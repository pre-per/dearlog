import 'package:dearlog/app.dart';
import 'package:dearlog/diary/models/letter.dart';
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
    );
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    // letters 우선 파싱. 없으면 구버전(myLetter: String)을 단일 draft로 마이그레이션.
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
      title: json['title'],
      content: json['content'],
      emotion: json['emotion'],
      imageUrls: List<String>.from(json['imageUrls']),
      callId: json['callId'],
      letters: letters,
      aiComment: json['aiComment'],
      analysis: json['analysis'] != null
          ? DiaryAnalysis.fromJson(Map<String, dynamic>.from(json['analysis']))
          : null,
      nlpInsight: json['nlpInsight'] != null
          ? NLPInsight.fromJson(
              Map<String, dynamic>.from(json['nlpInsight']))
          : null,
    );
  }

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
    };
  }
}
