import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/crypto/diary_crypto.dart';
import '../../core/crypto/encrypted_field.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';
import '../models/user_traits.dart';

/// `users/{uid}` 문서 접근.
///
/// `profile` 서브맵 — nickname, gender, ageGroup, interests — 은 KMS envelope
/// 으로 암호화한다. 다른 사용자/운영자가 콘솔에서 nickname/gender/ageGroup 같은
/// 식별성 정보를 평문으로 보지 못하게 하기 위함.
///
/// 평문 유지:
///   - email, isCompleted, fcmToken, commentNotifEnabled, 약관 동의 시각 등
///     운영 메타데이터 (Cloud Functions 가 직접 읽어서 push/inbox 처리)
///   - traits, preferences — 현재 매칭 기능에서만 사용. 필요 시 추후 별도 암호화.
///
/// 마이그레이션:
///   - 기존 평문 profile 은 그대로 읽힘. 사용자가 한 번이라도 프로필을 저장하면
///     그 시점부터 암호화된 형태로 덮어써진다.
class UserRepository {
  final FirebaseFirestore firestore;
  final DiaryCrypto crypto;

  UserRepository({
    required this.firestore,
    DiaryCrypto? crypto,
  }) : crypto = crypto ?? DiaryCrypto.instance;

  /// 사용자 문서를 읽어서 [UserModel] 로 변환.
  /// 문서가 없으면 null. 네트워크/권한 에러는 호출자에게 throw.
  Future<UserModel?> fetchUser(String userId) async {
    final docSnap = await firestore.doc('users/$userId').get();
    if (!docSnap.exists) return null;
    final data = docSnap.data()!;

    final profileRaw =
        data['profile'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final profile = await _decryptProfile(profileRaw);

    return UserModel(
      id: userId,
      email: data['email'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      profile: profile,
      preferences: UserPreferences.fromJson(
          data['preferences'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      traits: UserTraits.fromJson(
          data['traits'] as Map<String, dynamic>? ?? <String, dynamic>{}),
    );
  }

  /// 신규 사용자 초기 문서 생성.
  /// 빈 profile 은 민감 정보가 없으므로 굳이 암호화하지 않는다 — 첫 진짜 저장
  /// (onboarding 완료 시 [saveProfile]) 부터 KMS envelope 으로 들어간다.
  Future<void> initializeNewUser({
    required String userId,
    required String email,
  }) async {
    await firestore.doc('users/$userId').set({
      'email': email,
      'isCompleted': false,
      'profile': UserProfile.empty().toJson(),
      'preferences': UserPreferences(
              preferredGender: '', ageRange: [0, 0], relationshipType: '')
          .toJson(),
      'traits': UserTraits(
              emotions: [],
              personality: '',
              interestsScore: {},
              lastAnalyzedAt: DateTime.now())
          .toJson(),
      'matches': [],
    });
  }

  Future<void> updateIsCompleted(String userId, bool completed) async {
    await firestore.doc('users/$userId').update({'isCompleted': completed});
  }

  Future<void> saveProfile(String userId, UserProfile profile) async {
    final encryptedProfile = await _encryptProfile(profile);
    // update 로 `profile` 필드를 통째로 교체 — 이전 평문 nickname/gender/...
    // 잔재가 깔끔하게 사라진다. (set+merge 로 하면 inner 필드가 남을 수 있음)
    await firestore.doc('users/$userId').update({'profile': encryptedProfile});
  }

  Future<void> savePreferences(
      String userId, UserPreferences preferences) async {
    await firestore.doc('users/$userId').set(
        {'preferences': preferences.toJson()}, SetOptions(merge: true));
  }

  Future<void> saveTraits(String userId, UserTraits traits) async {
    await firestore
        .doc('users/$userId')
        .set({'traits': traits.toJson()}, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────
  // 암호화 / 복호화 헬퍼
  // ─────────────────────────────────────────────────

  /// 평문 [UserProfile] → Firestore 에 저장될 암호화 raw map.
  Future<Map<String, dynamic>> _encryptProfile(UserProfile profile) async {
    final dek = await crypto.createDocDek();
    final wrappedDek = await crypto.wrapDek(dek);
    final ef = await crypto.encrypt(jsonEncode(profile.toJson()), dek);
    return {
      'wrappedDek': wrappedDek,
      'encVersion': 1,
      'data': ef.toJson(),
    };
  }

  /// raw map → 평문 [UserProfile]. `wrappedDek` 가 있으면 복호화, 없으면 legacy
  /// 평문으로 간주. 복호화 실패는 빈 프로필로 폴백 (UI 가 깨지지 않게).
  Future<UserProfile> _decryptProfile(Map<String, dynamic> raw) async {
    if (raw['wrappedDek'] is! String) {
      return UserProfile.fromJson(raw);
    }
    try {
      final dek = await crypto.unwrapDek(raw['wrappedDek'] as String);
      final dataRaw = raw['data'];
      if (!EncryptedField.isEncryptedJson(dataRaw)) {
        return UserProfile.empty();
      }
      final ef =
          EncryptedField.fromJson(Map<String, dynamic>.from(dataRaw as Map));
      final plain = await crypto.decrypt(ef, dek);
      final decoded = jsonDecode(plain);
      if (decoded is! Map) return UserProfile.empty();
      return UserProfile.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UserRepository] profile decrypt 실패: $e');
      }
      return UserProfile.empty();
    }
  }
}
