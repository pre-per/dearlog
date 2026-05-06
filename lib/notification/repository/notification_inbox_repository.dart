import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_record.dart';

/// 알림 보관함의 Firestore 접근 단일 진입점.
///
/// - 적재는 Cloud Functions(`functions/index.js`) 가 담당 — 클라이언트는 읽기/읽음 처리/cleanup 만.
class NotificationInboxRepository {
  final FirebaseFirestore firestore;

  NotificationInboxRepository({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      firestore.collection('users').doc(uid).collection('notifications');

  /// 최신순 알림 라이브 구독.
  Stream<List<NotificationRecord>> watch(String uid, {int limit = 50}) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => NotificationRecord.fromJson(d.data())).toList());
  }

  /// 안 읽은 알림 개수 라이브 구독 (미읽음 배지용).
  Stream<int> watchUnreadCount(String uid) {
    return _col(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// 안 읽은 알림 모두 읽음 처리. 보관함 화면 진입 시 호출.
  Future<void> markAllRead(String uid) async {
    final snap = await _col(uid).where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// 30일 이상 된 알림 자동 정리.
  /// 화면 진입 시 fire-and-forget 으로 호출하면 Firestore 비용을 적게 유지할 수 있다.
  Future<void> deleteOlderThan(String uid, Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    final snap = await _col(uid)
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    if (snap.docs.isEmpty) return;
    final batch = firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
