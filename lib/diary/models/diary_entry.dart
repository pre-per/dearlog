import 'package:dearlog/app.dart';
import 'package:dearlog/core/crypto/encrypted_field.dart';
import 'package:dearlog/diary/models/letter.dart';
import 'package:dearlog/diary/models/music_recommendation.dart';
import 'package:dearlog/diary/models/nlp_insight.dart';

class DiaryEntry {
  final String id;
  final DateTime date;
  final String title;
  final String content;
  final String emotion;
  final List<String> imageUrls;
  final String? callId;
  final List<Letter> letters;
  final String? aiComment;

  final DiaryAnalysis? analysis;

  /// NLP 심리 인사이트 — 첫 진입 시 사용자가 "지금 분석하기"를 탭하면 lazy 생성.
  final NLPInsight? nlpInsight;

  /// 일기 내용에 어울리는 음악 추천 — 신규 일기는 자동 생성, 기존 일기는 사용자가 "추천 받기" 누르면 생성.
  final MusicRecommendation? music;

  DiaryEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    required this.emotion,
    required this.imageUrls,
    this.callId,
    List<Letter>? letters,
    this.aiComment,
    this.analysis,
    this.nlpInsight,
    this.music,
  }) : letters = letters ?? const [];

  DiaryEntry copyWith({
    String? id,
    DateTime? date,
    String? title,
    String? content,
    String? emotion,
    List<String>? imageUrls,
    String? callId,
    List<Letter>? letters,
    String? aiComment,
    DiaryAnalysis? analysis,
    NLPInsight? nlpInsight,
    MusicRecommendation? music,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      content: content ?? this.content,
      emotion: emotion ?? this.emotion,
      imageUrls: imageUrls ?? List<String>.from(this.imageUrls),
      callId: callId ?? this.callId,
      letters: letters ?? List<Letter>.from(this.letters),
      aiComment: aiComment ?? this.aiComment,
      analysis: analysis ?? this.analysis,
      nlpInsight: nlpInsight ?? this.nlpInsight,
      music: music ?? this.music,
    );
  }

  /// 평문 도메인 객체로 변환 (암호화 처리 없음). 호출자는 legacy 평문 doc 또는
  /// 이미 복호화된 doc 을 넘긴다고 가정. Firestore 에서 직접 읽을 땐
  /// [DiaryRepository] 가 복호화 후 이걸 호출한다.
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final lettersRaw = json['letters'] as List?;
    List<Letter> letters;
    if (lettersRaw != null) {
      letters = lettersRaw
          .map((e) => Letter.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      final legacy = json['myLetter'] as String?;
      if (legacy != null && legacy.trim().isNotEmpty) {
        letters = [
          Letter(
            id: 'legacy_${json['id']}',
            content: legacy,
            createdAt: DateTime.parse(json['date']),
          ),
        ];
      } else {
        letters = const [];
      }
    }

    return DiaryEntry(
      id: json['id'],
      date: DateTime.parse(json['date']),
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      emotion: json['emotion'],
      imageUrls: List<String>.from(json['imageUrls']),
      callId: json['callId'],
      letters: letters,
      aiComment: json['aiComment'] as String?,
      analysis: json['analysis'] != null
          ? DiaryAnalysis.fromJson(Map<String, dynamic>.from(json['analysis']))
          : null,
      nlpInsight: json['nlpInsight'] != null
          ? NLPInsight.fromJson(
              Map<String, dynamic>.from(json['nlpInsight']))
          : null,
      music: json['music'] != null
          ? MusicRecommendation.fromJson(
              Map<String, dynamic>.from(json['music']))
          : null,
    );
  }

  /// 평문 toJson — 마이그레이션 안 된 legacy 포맷이 필요할 때만.
  /// 새 저장 흐름은 [DiaryRepository] 가 암호화 후 별도 toJson 을 사용한다.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'content': content,
      'emotion': emotion,
      'imageUrls': imageUrls,
      if (callId != null) 'callId': callId,
      if (letters.isNotEmpty)
        'letters': letters.map((l) => l.toJson()).toList(),
      if (aiComment != null) 'aiComment': aiComment,
      if (analysis != null) 'analysis': analysis!.toJson(),
      if (nlpInsight != null) 'nlpInsight': nlpInsight!.toJson(),
      if (music != null) 'music': music!.toJson(),
    };
  }
}

/// Firestore raw map 이 KMS envelope 포맷(`wrappedDek` 보유)인지 판별.
bool diaryRawIsEncrypted(Map<String, dynamic> raw) {
  return raw['wrappedDek'] is String &&
      EncryptedField.isEncryptedJson(raw['content']);
}
