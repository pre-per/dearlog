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

}
