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

  /// ✅ 일기 추가/덮어쓰기.
  /// 이미지 URL 처리:
  /// - 이미 우리 Storage에 있는 URL (firebasestorage.googleapis.com / gs://) → 그대로 보존.
  ///   (이전엔 매 저장마다 재다운로드 → 토큰 만료 시 403. 이게 편지 추가/삭제 때 자주 떴던 원인.)
  /// - 외부 임시 URL (OpenAI 등) → 1회 다운로드 후 우리 Storage로 업로드/교체.
  /// - 외부 URL 다운로드 실패 시 → 원본 URL 보존하고 저장은 계속 진행.
  ///   (이미지 한 장 때문에 일기/편지 본문 저장이 막히지 않도록.)
  Future<void> saveDiary(String userId, DiaryEntry entry) async {
    final originalUrls = entry.imageUrls;

    final convertedUrls = <String>[];
    for (int i = 0; i < originalUrls.length; i++) {
      final url = originalUrls[i];

      // 이미 우리 Storage에 있는 URL이면 재업로드 불필요 → 그대로 사용.
      final isAlreadyOurs =
          url.startsWith('https://firebasestorage.googleapis.com') ||
              url.startsWith('gs://');
      if (isAlreadyOurs) {
        convertedUrls.add(url);
        continue;
      }

      final isExternalWebUrl =
          url.startsWith('http://') || url.startsWith('https://');
      if (!isExternalWebUrl) {
        // 알 수 없는 형식은 그대로 보존
        convertedUrls.add(url);
        continue;
      }

      // 외부 임시 URL 1회 업로드 시도. 실패해도 본문 저장은 진행.
      try {
        final firebaseUrl = await _uploadImageFromUrl(
          userId: userId,
          diaryId: entry.id,
          index: i,
          imageUrl: url,
        );
        convertedUrls.add(firebaseUrl);
      } catch (e) {
        // OpenAI 임시 링크 만료 등은 일상적이므로 silent.
        // ignore: avoid_print
        print('[saveDiary] 외부 이미지 업로드 실패 — 원본 URL 보존: $e');
        convertedUrls.add(url);
      }
    }

    final updatedEntry = entry.copyWith(imageUrls: convertedUrls);

    await _diaryCollection(userId).doc(updatedEntry.id).set(updatedEntry.toJson());
  }

  /// 일기 삭제 (선택: 이미지도 같이 삭제)
  /// 일기 삭제 + (가능하면) 연결된 이미지도 Storage에서 삭제
  Future<void> deleteDiary(String userId, String diaryId) async {
    // 1) 먼저 문서 읽어서 imageUrls 확보 (문서가 없으면 그냥 삭제 시도)
    final docRef = _diaryCollection(userId).doc(diaryId);
    final doc = await docRef.get();

    final List<String> imageUrls = doc.data()?['imageUrls'] != null
        ? List<String>.from(doc.data()!['imageUrls'])
        : const [];

    // 2) Storage 이미지 삭제 (URL로 지울 수 있는 것만)
    // - downloadURL(https://firebasestorage...)이면 refFromURL로 삭제 가능
    // - gs://... 도 refFromURL로 삭제 가능
    // - http(s) 임시 링크(OpenAI) 같은 건 Storage 파일이 아니라서 스킵
    for (final url in imageUrls) {
      try {
        final isFirebaseUrl =
            url.startsWith('https://firebasestorage.googleapis.com') ||
                url.startsWith('gs://');

        if (!isFirebaseUrl) continue;

        final ref = storage.refFromURL(url);
        await ref.delete();
      } catch (_) {
        // 일부 파일이 이미 없거나 권한 문제로 실패할 수 있음 → 전체 삭제 흐름은 계속 진행
      }
    }

    // 3) 혹시 위에서 못 지운 파일이 폴더에 남아있을 수 있으니 폴더 경로 기준으로도 정리(선택)
    //    네가 저장한 경로 규칙을 따르므로 안전하게 싹 지움
    try {
      final folderRef = storage.ref('users/$userId/diaries/$diaryId');
      final list = await folderRef.listAll();

      // files
      for (final item in list.items) {
        try {
          await item.delete();
        } catch (_) {}
      }

      // subfolders (혹시 생겼다면)
      for (final prefix in list.prefixes) {
        try {
          final sub = await prefix.listAll();
          for (final item in sub.items) {
            try {
              await item.delete();
            } catch (_) {}
          }
        } catch (_) {}
      }
    } catch (_) {}

    // 4) 마지막으로 Firestore 문서 삭제
    await docRef.delete();
  }

  // diary_repository.dart 안에 추가
  Stream<List<DiaryEntry>> watchDiaries(String userId) {
    return _diaryCollection(userId)
    // date 필드가 ISO 문자열이면 orderBy가 문자열 기준으로도 정렬되긴 하는데,
    // 가능하면 Timestamp로 저장하는 걸 추천(아래 참고)
        .orderBy('date') // 최신이 아래로 가게 (원하면 descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => DiaryEntry.fromJson(doc.data())).toList();
    });
  }

  Future<DiaryEntry?> fetchLatestDiary(String userId) async {
    final snap = await _diaryCollection(userId)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return DiaryEntry.fromJson(snap.docs.first.data());
  }

  /// 최근 [limit]개 일기 (최신순). 통화 시스템 프롬프트에 컨텍스트로 주입할 때 사용.
  Future<List<DiaryEntry>> fetchRecentDiaries(
    String userId, {
    int limit = 3,
  }) async {
    final snap = await _diaryCollection(userId)
        .orderBy('date', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) => DiaryEntry.fromJson(doc.data())).toList();
  }

  Future<DiaryEntry?> fetchDiaryById(String userId, String diaryId) async {
    final doc = await _diaryCollection(userId).doc(diaryId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return DiaryEntry.fromJson(data);
  }
}
