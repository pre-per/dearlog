class UserTraits {
  final List<String> emotions;
  final String personality;
  final Map<String, double> interestsScore;
  final DateTime lastAnalyzedAt;

  UserTraits({
    required this.emotions,
    required this.personality,
    required this.interestsScore,
    required this.lastAnalyzedAt,
  });

  factory UserTraits.fromJson(Map<String, dynamic> json) {
    return UserTraits(
      emotions: List<String>.from(json['emotions']),
      personality: json['personality'],
      interestsScore: Map<String, double>.from(json['interestsScore']),
      lastAnalyzedAt: DateTime.parse(json['lastAnalyzedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emotions': emotions,
      'personality': personality,
      'interestsScore': interestsScore,
      'lastAnalyzedAt': lastAnalyzedAt.toIso8601String(),
    };
  }
}
