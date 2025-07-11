import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dearlog/diary/models/diary_entry.dart';

class DiaryRepository {
  final FirebaseFirestore firestore;

  DiaryRepository({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return firestore.collection('users').doc(userId);
  }

  /// 전체 일기 불러오기
  Future<List<DiaryEntry>> fetchDiaries(String userId) async {
    final doc = await _userDoc(userId).get();
    final data = doc.data();
    if (data == null || data['diaries'] == null) return [];

    final rawList = data['diaries'] as List<dynamic>;
    return rawList.map((e) => DiaryEntry.fromJson(e)).toList();
  }

  /// 일기 추가 (덮어쓰기)
  Future<void> saveDiaries(String userId, List<DiaryEntry> diaries) async {
    await _userDoc(userId).set({
      'diaries': diaries.map((e) => e.toJson()).toList(),
    }, SetOptions(merge: true));
  }

  /// 일기 추가 (기존에 append)
  Future<void> addDiary(String userId, DiaryEntry newEntry) async {
    final current = await fetchDiaries(userId);
    current.insert(0, newEntry); // 최신순 정렬 시 앞에 삽입
    await saveDiaries(userId, current);
  }

  /// 일기 수정
  Future<void> updateDiary(String userId, DiaryEntry updatedEntry) async {
    final current = await fetchDiaries(userId);
    final index = current.indexWhere((e) => e.id == updatedEntry.id);
    if (index == -1) return;

    current[index] = updatedEntry;
    await saveDiaries(userId, current);
  }

  /// 일기 삭제
  Future<void> deleteDiary(String userId, String diaryId) async {
    final current = await fetchDiaries(userId);
    current.removeWhere((e) => e.id == diaryId);
    await saveDiaries(userId, current);
  }
}
