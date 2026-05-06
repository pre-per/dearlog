/// AI가 한 달치 일기를 보고 생성하는 인사이트.
/// Firestore `users/{uid}/insights/{yyyy-MM}` 문서에 캐시.
class MonthlyInsight {
  /// "yyyy-MM" 포맷. 예: "2026-05".
  final String monthKey;

  /// 한 줄(2~3문장) 회고.
  final String summary;

  /// 자동 발견된 반복 패턴 (1~3개).
  final List<DiscoveredPattern> patterns;

  /// 캐시 시점.
  final DateTime generatedAt;

  /// 생성 당시의 일기 갯수 — UI에 "N개 일기 기반" 표시용.
  final int diaryCount;

  const MonthlyInsight({
    required this.monthKey,
    required this.summary,
    required this.patterns,
    required this.generatedAt,
    required this.diaryCount,
  });

  factory MonthlyInsight.fromJson(Map<String, dynamic> json) {
    return MonthlyInsight(
      monthKey: json['monthKey'] as String,
      summary: json['summary'] as String? ?? '',
      patterns: (json['patterns'] as List? ?? [])
          .map((e) => DiscoveredPattern.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      diaryCount: (json['diaryCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'monthKey': monthKey,
        'summary': summary,
        'patterns': patterns.map((p) => p.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
        'diaryCount': diaryCount,
      };

  static String monthKeyFor(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';
}

class DiscoveredPattern {
  /// 짧은 헤드라인. 예: "주말마다 카페가 자주 등장했어요"
  final String title;

  /// 1~2문장 부연. 예: "평균 +35로 안정 효과를 줬을 가능성이 있어요"
  final String body;

  const DiscoveredPattern({required this.title, required this.body});

  factory DiscoveredPattern.fromJson(Map<String, dynamic> json) =>
      DiscoveredPattern(
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
      };
}
