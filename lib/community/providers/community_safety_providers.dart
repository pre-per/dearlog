import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/providers/user_fetch_providers.dart';

/// 신고가 이 횟수 이상 누적된 게시물은 운영자 검토 전까지 피드/상세에서 숨긴다.
/// App Store 가이드라인 1.2 — 신고된 콘텐츠에 대한 조치 메커니즘.
const int kReportHideThreshold = 3;

/// 내 user 문서의 차단 목록 라이브 구독. {차단한 uid: 차단 당시 표시 이름}
///
/// user 문서 루트의 평문 필드(blockedUsers)라 KMS 암호화된 profile 과 무관하고,
/// firestore.rules 의 "본인 문서 read/write 허용" 규칙으로 그대로 동작한다.
final blockedUsersProvider = StreamProvider<Map<String, String>>((ref) {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return Stream.value(const {});
  return FirebaseFirestore.instance.doc('users/$uid').snapshots().map((snap) {
    final raw = snap.data()?['blockedUsers'];
    if (raw is! Map) return const <String, String>{};
    return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '익명'));
  });
});

/// 차단한 uid 집합 — 피드/댓글 필터링용.
final blockedUidsProvider = Provider<Set<String>>((ref) {
  return ref.watch(blockedUsersProvider).maybeWhen(
        data: (m) => m.keys.toSet(),
        orElse: () => const <String>{},
      );
});

/// 커뮤니티 이용 규칙 동의 여부 (users/{uid}.communityRulesAgreedAt 존재 여부).
final communityRulesAgreedProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .doc('users/$uid')
      .snapshots()
      .map((snap) => snap.data()?['communityRulesAgreedAt'] != null);
});

/// 차단/해제/규칙 동의 — 전부 본인 user 문서 루트 필드만 수정한다.
class CommunitySafetyActions {
  CommunitySafetyActions._();

  static Future<void> blockUser({
    required String myUid,
    required String targetUid,
    required String displayName,
  }) async {
    await FirebaseFirestore.instance.doc('users/$myUid').set({
      'blockedUsers': {targetUid: displayName},
    }, SetOptions(merge: true));
  }

  static Future<void> unblockUser({
    required String myUid,
    required String targetUid,
  }) async {
    await FirebaseFirestore.instance.doc('users/$myUid').update({
      'blockedUsers.$targetUid': FieldValue.delete(),
    });
  }

  static Future<void> agreeCommunityRules(String myUid) async {
    await FirebaseFirestore.instance.doc('users/$myUid').set({
      'communityRulesAgreedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
