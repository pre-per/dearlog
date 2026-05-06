import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dearlog/diary/models/monthly_insight.dart';

/// 월별 AI 인사이트 캐시 저장소.
/// 경로: users/{uid}/insights/{yyyy-MM}
class InsightRepository {
  final FirebaseFirestore firestore;

  InsightRepository({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _coll(String userId) {
    return firestore.collection('users').doc(userId).collection('insights');
  }

  Future<MonthlyInsight?> fetch(String userId, String monthKey) async {
    final doc = await _coll(userId).doc(monthKey).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    try {
      return MonthlyInsight.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String userId, MonthlyInsight insight) async {
    await _coll(userId).doc(insight.monthKey).set(insight.toJson());
  }

  /// 실시간 구독 — 다른 기기에서 갱신되거나 캐시가 새로 쓰일 때 자동 반영.
  Stream<MonthlyInsight?> watch(String userId, String monthKey) {
    return _coll(userId).doc(monthKey).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      try {
        return MonthlyInsight.fromJson(data);
      } catch (_) {
        return null;
      }
    });
  }
}
