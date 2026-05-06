import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';
import '../models/user_traits.dart';

class UserRepository {
  final FirebaseFirestore firestore;
  UserRepository({required this.firestore});

  /// 사용자 문서를 읽어서 [UserModel] 로 변환.
  /// 문서가 없으면 null. 네트워크/권한 에러는 호출자에게 throw.
  Future<UserModel?> fetchUser(String userId) async {
    final docSnap = await firestore.doc('users/$userId').get();
    if (!docSnap.exists) return null;
    final data = docSnap.data()!;
    return UserModel(
      id: userId,
      email: data['email'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      profile: UserProfile.fromJson(
          data['profile'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      preferences: UserPreferences.fromJson(
          data['preferences'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      traits: UserTraits.fromJson(
          data['traits'] as Map<String, dynamic>? ?? <String, dynamic>{}),
    );
  }

  /// 신규 사용자 초기 문서 생성.
  /// 실패 시 throw — 호출자(login flow) 가 사용자에게 안내하고 정상 종료시켜야 한다.
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
    await firestore.doc('users/$userId').set({'profile': profile.toJson()}, SetOptions(merge: true));
  }

  Future<void> savePreferences(String userId, UserPreferences preferences) async {
    await firestore.doc('users/$userId').set({'preferences': preferences.toJson()}, SetOptions(merge: true));
  }

  Future<void> saveTraits(String userId, UserTraits traits) async {
    await firestore.doc('users/$userId').set({'traits': traits.toJson()}, SetOptions(merge: true));
  }
}
