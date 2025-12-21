import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import 'package:dearlog/diary/models/diary_entry.dart';

class DiaryRepository {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  DiaryRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _diaryCollection(String userId) {
    return firestore.collection('users').doc(userId).collection('diary');
  }

  Reference _diaryImageRef(String userId, String diaryId, int index) {
    // 여러 장 이미지 대비해서 index 포함
    return storage.ref('users/$userId/diaries/$diaryId/image_$index.png');
  }

  Future<String> _uploadImageFromUrl({
    required String userId,
    required String diaryId,
    required int index,
    required String imageUrl,
  }) async {
    // 1) 다운로드
    final res = await http.get(Uri.parse(imageUrl));
    if (res.statusCode != 200) {
      throw Exception('이미지 다운로드 실패: ${res.statusCode}');
    }
    final Uint8List bytes = res.bodyBytes;

    // 2) 업로드
    final ref = _diaryImageRef(userId, diaryId, index);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/png',
        cacheControl: 'public,max-age=31536000',
      ),
    );

    // 3) downloadURL
    return await ref.getDownloadURL();
  }

  /// 전체 일기 불러오기
  Future<List<DiaryEntry>> fetchDiaries(String userId) async {
    final snapshot = await _diaryCollection(userId).get();
    return snapshot.docs.map((doc) => DiaryEntry.fromJson(doc.data())).toList();
  }

  /// ✅ 일기 추가/덮어쓰기 (이미지 URL이 http(s)면 Storage 업로드 후 교체)
  Future<void> saveDiary(String userId, DiaryEntry entry) async {
    final originalUrls = entry.imageUrls ?? [];

    // OpenAI 임시 링크처럼 http(s) 인 경우 업로드해서 교체
    final convertedUrls = <String>[];
    for (int i = 0; i < originalUrls.length; i++) {
      final url = originalUrls[i];
      final isWebUrl = url.startsWith('http://') || url.startsWith('https://');

      if (isWebUrl) {
        final firebaseUrl = await _uploadImageFromUrl(
          userId: userId,
          diaryId: entry.id,
          index: i,
          imageUrl: url,
        );
        convertedUrls.add(firebaseUrl);
      } else {
        // 이미 firebase url / gs:// 등인 경우 그대로
        convertedUrls.add(url);
      }
    }

    final updatedEntry = entry.copyWith(imageUrls: convertedUrls);

    await _diaryCollection(userId).doc(updatedEntry.id).set(updatedEntry.toJson());
  }

  /// 일기 삭제 (선택: 이미지도 같이 삭제)
  Future<void> deleteDiary(String userId, String diaryId) async {
    await _diaryCollection(userId).doc(diaryId).delete();

    // 선택: 이미지도 삭제하고 싶다면 (경로 규칙이 일정할 때만)
    // try { await storage.ref('users/$userId/diaries/$diaryId').listAll() ... } catch {}
  }
}
