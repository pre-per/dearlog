class DiaryAnalysis {
  final String summary;
  final int moodScore; // 0~100
  final String valence; // positive|neutral|negative
  final List<String> mainWords;
  final List<EmotionScore> emotions; // Top3 권장
  final List<EvidenceQuote> evidence; // 2~3개
  final List<Recommendation> recommendations; // 3개
  final String riskLevel; // low|medium|high

  DiaryAnalysis({
    required this.summary,
    required this.moodScore,
    required this.valence,
    required this.mainWords,
    required this.emotions,
    required this.evidence,
    required this.recommendations,
    required this.riskLevel,
  });

  factory DiaryAnalysis.fromJson(Map<String, dynamic> json) {
    return DiaryAnalysis(
      summary: json['summary'] ?? '',
      moodScore: (json['moodScore'] ?? 50) as int,
      valence: json['valence'] ?? 'neutral',
      mainWords: List<String>.from(json['mainWords'] ?? const []),
      emotions: (json['emotions'] as List? ?? [])
          .map((e) => EmotionScore.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      evidence: (json['evidence'] as List? ?? [])
          .map((e) => EvidenceQuote.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      recommendations: (json['recommendations'] as List? ?? [])
          .map((e) => Recommendation.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      riskLevel: json['riskLevel'] ?? 'low',
    );
  }

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'moodScore': moodScore,
    'valence': valence,
    'mainWords': mainWords,
    'emotions': emotions.map((e) => e.toJson()).toList(),
    'evidence': evidence.map((e) => e.toJson()).toList(),
    'recommendations': recommendations.map((e) => e.toJson()).toList(),
    'riskLevel': riskLevel,
  };
}

class EmotionScore {
  final String name; // "불안" 등
  final int score; // 0~100
  final List<String> keywords_emotion;

  EmotionScore({required this.name, required this.score, required this.keywords_emotion});

  factory EmotionScore.fromJson(Map<String, dynamic> json) => EmotionScore(
    name: json['name'] ?? '',
    score: (json['score'] ?? 0) as int,
    keywords_emotion: List<String>.from(json['keywords_emotion'] ?? const []),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'keywords_emotion': keywords_emotion,
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

class Recommendation {
  final String title;
  final int minutes;
  final List<String> steps;

  Recommendation({required this.title, required this.minutes, required this.steps});

  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(
    title: json['title'] ?? '',
    minutes: (json['minutes'] ?? 10) as int,
    steps: List<String>.from(json['steps'] ?? const []),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'minutes': minutes,
    'steps': steps,
  };
}
