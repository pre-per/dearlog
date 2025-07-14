import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dearlog/diary/models/diary_entry.dart';

class DiaryRepository {
  final FirebaseFirestore firestore;

  DiaryRepository({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _diaryCollection(String userId) {
    return firestore.collection('users').doc(userId).collection('diary');
  }

  /// 전체 일기 불러오기
  Future<List<DiaryEntry>> fetchDiaries(String userId) async {
    final snapshot = await _diaryCollection(userId).get();
    return snapshot.docs.map((doc) => DiaryEntry.fromJson(doc.data())).toList();
  }

  /// 일기 추가 또는 덮어쓰기 (id 기준)
  Future<void> saveDiary(String userId, DiaryEntry entry) async {
    await _diaryCollection(userId).doc(entry.id).set(entry.toJson());
  }

  /// 일기 삭제
  Future<void> deleteDiary(String userId, String diaryId) async {
    await _diaryCollection(userId).doc(diaryId).delete();
  }
}
