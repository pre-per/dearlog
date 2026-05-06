// 음/양/중립 감정 매핑 — moodScore 폴백 계산용.
// 통화 알림 메시지 빌더(reminder_message_builder.dart)와 동일 매핑이지만
// 모델 자체에서도 폴백 계산이 가능해야 해서 여기 둠.
const Set<String> _negativeEmotions = {'슬픔', '외로움', '우울', '분노', '짜증', '답답함'};
const Set<String> _positiveEmotions = {
  '평온', '안정', '차분', '기쁨', '설렘', '즐거움', '행복', '만족', '감사'
};

class DiaryAnalysis {
  /// -100 (매우 부정) ~ 0 (평소) ~ +100 (매우 긍정).
  /// 분석 단계에서 LLM이 채워줌. 구 데이터(필드 없음)는 emotions 기반 폴백 계산.
  final int moodScore;
  final List<EmotionScore> emotions;
  final List<KeywordEntry> keywords;
  final List<EvidenceQuote> evidence;

  DiaryAnalysis({
    required this.moodScore,
    required this.emotions,
    required this.keywords,
    required this.evidence,
  });

  factory DiaryAnalysis.fromJson(Map<String, dynamic> json) {
    final emotions = (json['emotions'] as List? ?? [])
        .map((e) => EmotionScore.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // moodScore: 명시적 값이 있으면 사용, 없으면 emotions 기반 폴백.
    final raw = json['moodScore'];
    int score;
    if (raw is num) {
      score = raw.toInt().clamp(-100, 100);
    } else {
      score = _deriveMoodScoreFromEmotions(emotions);
    }

    return DiaryAnalysis(
      moodScore: score,
      emotions: emotions,
      keywords: (json['keywords'] as List? ?? [])
          .map((e) => KeywordEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      evidence: (json['evidence'] as List? ?? [])
          .map((e) => EvidenceQuote.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'moodScore': moodScore,
        'emotions': emotions.map((e) => e.toJson()).toList(),
        'keywords': keywords.map((e) => e.toJson()).toList(),
        'evidence': evidence.map((e) => e.toJson()).toList(),
      };

  /// emotions 리스트로부터 moodScore 추정 (구 데이터 호환).
  /// 가장 강한 감정의 valence × score.
  static int _deriveMoodScoreFromEmotions(List<EmotionScore> emotions) {
    if (emotions.isEmpty) return 0;
    final top = emotions.first;
    final n = top.name;
    final s = top.score.clamp(0, 100);
    if (_negativeEmotions.contains(n)) return -s;
    if (_positiveEmotions.contains(n)) return s;
    return 0;
  }
}

class EmotionScore {
  final String name;
  final int score;

  EmotionScore({required this.name, required this.score});

  factory EmotionScore.fromJson(Map<String, dynamic> json) => EmotionScore(
    name: json['name'] ?? '',
    score: (json['score'] ?? 0) as int,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
  };
}

enum KeywordCategory { emotion, noun }

KeywordCategory _categoryFromJson(String? v) {
  switch (v) {
    case 'emotion':
      return KeywordCategory.emotion;
    case 'noun':
    default:
      return KeywordCategory.noun;
  }
}

String _categoryToJson(KeywordCategory c) {
  switch (c) {
    case KeywordCategory.emotion:
      return 'emotion';
    case KeywordCategory.noun:
      return 'noun';
  }
}

class KeywordEntry {
  final String word;
  final KeywordCategory category;
  final String emotion;

  KeywordEntry({
    required this.word,
    required this.category,
    required this.emotion,
  });

  factory KeywordEntry.fromJson(Map<String, dynamic> json) => KeywordEntry(
    word: (json['word'] ?? '').toString().trim(),
    category: _categoryFromJson(json['category']),
    emotion: (json['emotion'] ?? '').toString().trim(),
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'category': _categoryToJson(category),
    'emotion': emotion,
  };
}

class EvidenceQuote {
  final String quote;
  final String why;

  EvidenceQuote({required this.quote, required this.why});

  factory EvidenceQuote.fromJson(Map<String, dynamic> json) => EvidenceQuote(
    quote: json['quote'] ?? '',
    why: json['why'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'quote': quote,
    'why': why,
  };
}
