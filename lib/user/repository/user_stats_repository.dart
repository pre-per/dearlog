import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_stats.dart';

/// `user_stats/{uid}` read-only 접근.
///
/// 통계 doc 은 Cloud Function (일기 onWrite 트리거 + 백필 callable) 만 쓰고
/// 클라이언트는 read 전용이다. 보안 규칙도 동일하게 강제한다.
///
/// 다른 사용자의 stats 도 조회 가능(랭크 배지/스트릭 글로우 표시용).
class UserStatsRepository {
  final FirebaseFirestore firestore;

  UserStatsRepository({required this.firestore});

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      firestore.doc('user_stats/$uid');

  /// 1회성 fetch. doc 이 없으면 null — 아직 한 번도 통계가 계산되지 않은 사용자.
  Future<UserStats?> fetch(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return UserStats.fromJson(data);
  }

  /// 실시간 스트림. doc 이 사라지거나 없으면 null emit.
  Stream<UserStats?> watch(String uid) {
    return _doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return UserStats.fromJson(data);
    });
  }
}
