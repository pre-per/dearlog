import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dearlog/diary/models/diary_entry.dart';

class DiaryRepository {
  final FirebaseFirestore firestore;

  DiaryRepository({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _diariesRef(String userId) {
    return firestore.collection('users').doc(userId).collection('diaries');
  }

  Future<List<DiaryEntry>> fetchDiaries(String userId) async {
    final snapshot = await _diariesRef(userId)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => DiaryEntry.fromJson(doc.data()))
        .toList();
  }

  Future<void> addDiary(String userId, DiaryEntry entry) async {
    await _diariesRef(userId).doc(entry.id).set(entry.toJson());
  }

  Future<void> deleteDiary(String userId, String diaryId) async {
    await _diariesRef(userId).doc(diaryId).delete();
  }

  Future<void> updateDiary(String userId, DiaryEntry entry) async {
    await _diariesRef(userId).doc(entry.id).update(entry.toJson());
  }
}
