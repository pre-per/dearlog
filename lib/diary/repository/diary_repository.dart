import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:dearlog/core/crypto/diary_crypto.dart';
import 'package:dearlog/core/crypto/encrypted_field.dart';
import 'package:dearlog/diary/models/diary_entry.dart';
import 'package:dearlog/diary/models/letter.dart';

class DiaryRepository {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final DiaryCrypto crypto;

  DiaryRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    DiaryCrypto? crypto,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        storage = storage ?? FirebaseStorage.instance,
        crypto = crypto ?? DiaryCrypto.instance;

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
    final res = await http.get(Uri.parse(imageUrl));
    if (res.statusCode != 200) {
      throw Exception('이미지 다운로드 실패: ${res.statusCode}');
    }
    final Uint8List bytes = res.bodyBytes;

    final ref = _diaryImageRef(userId, diaryId, index);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/png',
        cacheControl: 'public,max-age=31536000',
      ),
    );

    return await ref.getDownloadURL();
  }

  // ─────────────────────────────────────────────────
  // 암호화 doc ↔ DiaryEntry 변환
  // ─────────────────────────────────────────────────

  /// Firestore raw map → 평문 [DiaryEntry] 1건.
  /// 1) `wrappedDek` 가 있으면 KMS unwrap 후 각 필드 복호화
  /// 2) 없으면 legacy 평문으로 간주하고 그대로 사용
  /// 실패 시(예: 다른 사용자 doc 의 envelope) 본문은 placeholder 문자열로 대체.
  Future<DiaryEntry> _decryptDoc(Map<String, dynamic> raw) async {
    if (!diaryRawIsEncrypted(raw)) {
      return DiaryEntry.fromJson(raw);
    }
    try {
      final dek = await crypto.unwrapDek(raw['wrappedDek'] as String);
      return _decryptWithDek(raw, dek);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DiaryRepository] decrypt 실패 id=${raw['id']}: $e');
      }
      // 본문 노출 대신 안내문구로 채워 UI 가 깨지지 않게 함.
      // analysis/nlpInsight/emotion/music 도 암호문 그대로 두면 fromJson 이 깨지므로 정리.
      final raw2 = Map<String, dynamic>.from(raw);
      if (EncryptedField.isEncryptedJson(raw2['analysis'])) {
        raw2.remove('analysis');
      }
      if (EncryptedField.isEncryptedJson(raw2['nlpInsight'])) {
        raw2.remove('nlpInsight');
      }
      if (EncryptedField.isEncryptedJson(raw2['emotion'])) {
        raw2['emotion'] = '';
      }
      if (EncryptedField.isEncryptedJson(raw2['music'])) {
        raw2.remove('music');
      }
      return DiaryEntry.fromJson({
        ...raw2,
        'title': '(복호화 실패)',
        'content': '이 일기를 복호화할 수 없어요. 잠시 후 다시 시도해 주세요.',
        'aiComment': null,
        'letters': _stripLetterCiphertext(raw['letters']),
      });
    }
  }

  /// 이미 unwrap 된 [dek] 로 raw 의 모든 암호 필드를 복호화해 평문 [DiaryEntry] 생성.
  ///
  /// analysis / nlpInsight 는 두 가지 케이스 모두 지원:
  ///   - 새 포맷: EncryptedField (`{iv, ct}`) — JSON 문자열로 한 번 더 직렬화된 상태
  ///   - 옛 포맷: plain Map — 직전 버전에서 envelope 만 적용된 doc
  Future<DiaryEntry> _decryptWithDek(
    Map<String, dynamic> raw,
    SecretKey dek,
  ) async {
    final titleField = EncryptedField.fromJson(
        Map<String, dynamic>.from(raw['title'] as Map));
    final contentField = EncryptedField.fromJson(
        Map<String, dynamic>.from(raw['content'] as Map));
    final aiCommentRaw = raw['aiComment'];
    final aiCommentField = EncryptedField.isEncryptedJson(aiCommentRaw)
        ? EncryptedField.fromJson(Map<String, dynamic>.from(aiCommentRaw))
        : null;

    final titleFut = crypto.decrypt(titleField, dek);
    final contentFut = crypto.decrypt(contentField, dek);
    final aiCommentFut = aiCommentField == null
        ? Future<String?>.value(null)
        : crypto.decrypt(aiCommentField, dek).then<String?>((v) => v);

    // letters 본문도 같은 DEK 로 암호화되어 있음.
    final lettersRaw = (raw['letters'] as List?) ?? const [];
    final lettersFut = Future.wait(lettersRaw.map<Future<Letter>>((e) async {
      final map = Map<String, dynamic>.from(e as Map);
      final letter = Letter.fromJson(map);
      if (!letterRawHasEncryptedContent(map)) return letter;
      final ef =
          EncryptedField.fromJson(Map<String, dynamic>.from(map['content']));
      final plain = await crypto.decrypt(ef, dek);
      return letter.withContent(plain);
    }));

    // analysis / nlpInsight — EncryptedField 면 복호화 + JSON 디코드, plain Map 이면 그대로.
    final analysisFut = _decryptJsonField(raw['analysis'], dek);
    final nlpInsightFut = _decryptJsonField(raw['nlpInsight'], dek);
    // music — emotion 과 달리 nested map 이라 JSON 직렬화로 보낸 뒤 디코드.
    final musicFut = _decryptJsonField(raw['music'], dek);
    // emotion — 단일 string. EncryptedField 면 단순 복호화, 그냥 string 이면 통과.
    final emotionFut = _decryptStringField(raw['emotion'], dek);

    final results = await Future.wait([
      titleFut,
      contentFut,
      aiCommentFut,
      lettersFut,
      analysisFut,
      nlpInsightFut,
      musicFut,
      emotionFut,
    ]);

    final plainTitle = results[0] as String;
    final plainContent = results[1] as String;
    final plainAiComment = results[2] as String?;
    final plainLetters = results[3] as List<Letter>;
    final plainAnalysis = results[4] as Map<String, dynamic>?;
    final plainNlpInsight = results[5] as Map<String, dynamic>?;
    final plainMusic = results[6] as Map<String, dynamic>?;
    final plainEmotion = results[7] as String?;

    return DiaryEntry.fromJson({
      ...raw,
      'title': plainTitle,
      'content': plainContent,
      'aiComment': plainAiComment,
      'emotion': plainEmotion ?? '',
      'letters': plainLetters.map((l) => l.toJson()).toList(),
      if (plainAnalysis != null) 'analysis': plainAnalysis else 'analysis': null,
      if (plainNlpInsight != null)
        'nlpInsight': plainNlpInsight
      else
        'nlpInsight': null,
      if (plainMusic != null) 'music': plainMusic else 'music': null,
    });
  }

  /// raw 의 한 필드가 EncryptedField 면 복호화 후 String 으로, 이미 String 이면
  /// 그대로 반환. null/그 외는 null.
  Future<String?> _decryptStringField(Object? raw, SecretKey dek) async {
    if (raw == null) return null;
    if (raw is String) return raw;
    if (EncryptedField.isEncryptedJson(raw)) {
      final ef = EncryptedField.fromJson(Map<String, dynamic>.from(raw as Map));
      return crypto.decrypt(ef, dek);
    }
    return null;
  }

  /// raw map 의 한 필드가 EncryptedField 면 복호화 후 JSON 디코드, plain Map 이면
  /// 그대로 반환. null 이면 null. DiaryEntry.fromJson 이 받을 수 있는 Map 형태로
  /// 정규화한다.
  Future<Map<String, dynamic>?> _decryptJsonField(
    Object? raw,
    SecretKey dek,
  ) async {
    if (raw == null) return null;
    if (EncryptedField.isEncryptedJson(raw)) {
      final ef = EncryptedField.fromJson(Map<String, dynamic>.from(raw as Map));
      final plain = await crypto.decrypt(ef, dek);
      final parsed = jsonDecode(plain);
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
      return null;
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// 복호화에 실패한 doc 의 letters 에서 ciphertext content 만 빈 문자열로 치환.
  /// (그대로 두면 fromJson 이 `content` 를 Map 으로 받아 타입 에러)
  List<Map<String, dynamic>> _stripLetterCiphertext(Object? lettersRaw) {
    if (lettersRaw is! List) return const [];
    return lettersRaw.map<Map<String, dynamic>>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      if (letterRawHasEncryptedContent(m)) {
        m['content'] = '(복호화 실패)';
      }
      return m;
    }).toList();
  }

  /// 다중 doc 을 한 번에 복호화. KMS 호출을 batch 로 묶어 round-trip 절감.
  Future<List<DiaryEntry>> _decryptDocs(
      List<Map<String, dynamic>> docs) async {
    if (docs.isEmpty) return const [];

    // 1) wrappedDek 가 있는 doc 들의 인덱스만 모아 batch unwrap.
    final encryptedIdx = <int>[];
    final wrappedDeks = <String>[];
    for (int i = 0; i < docs.length; i++) {
      final raw = docs[i];
      if (diaryRawIsEncrypted(raw)) {
        encryptedIdx.add(i);
        wrappedDeks.add(raw['wrappedDek'] as String);
      }
    }

    final dekByIndex = <int, SecretKey>{};
    if (wrappedDeks.isNotEmpty) {
      try {
        final deks = await crypto.unwrapDeks(wrappedDeks);
        for (int j = 0; j < deks.length; j++) {
          final dek = deks[j];
          if (dek != null) dekByIndex[encryptedIdx[j]] = dek;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[DiaryRepository] batch unwrap 실패 → 개별 fallback: $e');
        }
        // batch 전체가 죽으면 아래 loop 에서 각 doc 별로 다시 시도.
      }
    }

    // 2) doc 별 디코드 (병렬). 평문 doc 은 동기적 변환.
    return Future.wait(docs.asMap().entries.map((entry) async {
      final i = entry.key;
      final raw = entry.value;
      if (!diaryRawIsEncrypted(raw)) {
        return DiaryEntry.fromJson(raw);
      }
      final dek = dekByIndex[i];
      if (dek != null) {
        try {
          return await _decryptWithDek(raw, dek);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[DiaryRepository] doc decrypt 실패 id=${raw['id']}: $e');
          }
        }
      }
      // batch unwrap 실패한 doc 은 단건 unwrap 으로 재시도.
      return _decryptDoc(raw);
    }));
  }

  /// 평문 [DiaryEntry] → Firestore 저장용 암호화 raw map.
  /// title, content, aiComment, emotion, music, 각 letter.content, analysis,
  /// nlpInsight 를 단일 DEK 로 묶어 암호화하고 `wrappedDek` 메타도 함께 set.
  ///
  /// 평문 유지: id, date, callId, imageUrls — 동작/조회용 메타데이터.
  Future<Map<String, dynamic>> _encryptEntry(DiaryEntry entry) async {
    final dek = await crypto.createDocDek();
    final wrappedDek = await crypto.wrapDek(dek);

    final titleField = await crypto.encrypt(entry.title, dek);
    final contentField = await crypto.encrypt(entry.content, dek);
    final aiCommentField = (entry.aiComment == null || entry.aiComment!.isEmpty)
        ? null
        : await crypto.encrypt(entry.aiComment!, dek);

    // emotion 은 짧은 string 라벨이지만 같은 DEK 로 묶어 저장.
    // 비어 있으면 굳이 암호화 칸 만들지 않고 필드 자체를 빼버린다 (읽을 때 '' 로 처리).
    Map<String, dynamic>? emotionEnc;
    if (entry.emotion.isNotEmpty) {
      final ef = await crypto.encrypt(entry.emotion, dek);
      emotionEnc = ef.toJson();
    }

    final letterDocs = await Future.wait(entry.letters.map((l) async {
      final ef = await crypto.encrypt(l.content, dek);
      final raw = l.toJson();
      raw['content'] = ef.toJson(); // 평문 string 자리에 EncryptedField 객체 삽입
      return raw;
    }));

    // analysis / nlpInsight / music 는 nested map 전체를 JSON 문자열로 직렬화 후 암호화.
    // 읽을 때 다시 jsonDecode → fromJson.
    Map<String, dynamic>? analysisEnc;
    if (entry.analysis != null) {
      final ef =
          await crypto.encrypt(jsonEncode(entry.analysis!.toJson()), dek);
      analysisEnc = ef.toJson();
    }
    Map<String, dynamic>? nlpInsightEnc;
    if (entry.nlpInsight != null) {
      final ef =
          await crypto.encrypt(jsonEncode(entry.nlpInsight!.toJson()), dek);
      nlpInsightEnc = ef.toJson();
    }
    Map<String, dynamic>? musicEnc;
    if (entry.music != null) {
      final ef = await crypto.encrypt(jsonEncode(entry.music!.toJson()), dek);
      musicEnc = ef.toJson();
    }

    final out = <String, dynamic>{
      'id': entry.id,
      'date': entry.date.toIso8601String(),
      'imageUrls': entry.imageUrls,
      if (entry.callId != null) 'callId': entry.callId,
      // 암호화 필드 + 봉투
      'wrappedDek': wrappedDek,
      'encVersion': 3,
      'title': titleField.toJson(),
      'content': contentField.toJson(),
      if (aiCommentField != null) 'aiComment': aiCommentField.toJson(),
      if (emotionEnc != null) 'emotion': emotionEnc,
      if (letterDocs.isNotEmpty) 'letters': letterDocs,
      if (analysisEnc != null) 'analysis': analysisEnc,
      if (nlpInsightEnc != null) 'nlpInsight': nlpInsightEnc,
      if (musicEnc != null) 'music': musicEnc,
    };
    return out;
  }

  // ─────────────────────────────────────────────────
  // 공개 API
  // ─────────────────────────────────────────────────

  /// 전체 일기 불러오기
  Future<List<DiaryEntry>> fetchDiaries(String userId) async {
    final snapshot = await _diaryCollection(userId).get();
    final docs = snapshot.docs.map((d) => d.data()).toList();
    return _decryptDocs(docs);
  }

  /// ✅ 일기 추가/덮어쓰기.
  /// 이미지 URL 처리는 이전과 동일. 본문/제목/AI 댓글/편지 본문은 envelope 암호화.
  Future<void> saveDiary(String userId, DiaryEntry entry) async {
    final originalUrls = entry.imageUrls;

    final convertedUrls = <String>[];
    for (int i = 0; i < originalUrls.length; i++) {
      final url = originalUrls[i];

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
        convertedUrls.add(url);
        continue;
      }

      try {
        final firebaseUrl = await _uploadImageFromUrl(
          userId: userId,
          diaryId: entry.id,
          index: i,
          imageUrl: url,
        );
        convertedUrls.add(firebaseUrl);
      } catch (e) {
        debugPrint('[saveDiary] 외부 이미지 업로드 실패 — 원본 URL 보존: $e');
        convertedUrls.add(url);
      }
    }

    final updatedEntry = entry.copyWith(imageUrls: convertedUrls);
    final encrypted = await _encryptEntry(updatedEntry);

    // 새 저장은 항상 전체 set — legacy 평문 필드가 남아있던 doc 도 자동으로 사라진다.
    await _diaryCollection(userId).doc(updatedEntry.id).set(encrypted);
  }

  /// 일기 삭제 + (가능하면) 연결된 이미지도 Storage에서 삭제
  Future<void> deleteDiary(String userId, String diaryId) async {
    final docRef = _diaryCollection(userId).doc(diaryId);
    final doc = await docRef.get();

    final List<String> imageUrls = doc.data()?['imageUrls'] != null
        ? List<String>.from(doc.data()!['imageUrls'])
        : const [];

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

    try {
      final folderRef = storage.ref('users/$userId/diaries/$diaryId');
      final list = await folderRef.listAll();

      for (final item in list.items) {
        try {
          await item.delete();
        } catch (_) {}
      }

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

    await docRef.delete();
  }

  /// 일기 실시간 스트림. snapshot 마다 모든 doc 을 batch unwrap → 복호화해
  /// 평문 [DiaryEntry] 리스트로 emit.
  Stream<List<DiaryEntry>> watchDiaries(String userId) {
    return _diaryCollection(userId)
        .orderBy('date')
        .snapshots()
        .asyncMap((snap) async {
      final docs = snap.docs.map((d) => d.data()).toList();
      return _decryptDocs(docs);
    });
  }

  Future<DiaryEntry?> fetchLatestDiary(String userId) async {
    final snap = await _diaryCollection(userId)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return _decryptDoc(snap.docs.first.data());
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

    final docs = snap.docs.map((d) => d.data()).toList();
    return _decryptDocs(docs);
  }

  Future<DiaryEntry?> fetchDiaryById(String userId, String diaryId) async {
    final doc = await _diaryCollection(userId).doc(diaryId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return _decryptDoc(data);
  }
}
