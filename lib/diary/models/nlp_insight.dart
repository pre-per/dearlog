/// NLP 심리 인사이트 — 신경언어프로그래밍(Neuro-Linguistic Programming) 기반.
/// 자연어처리(NLP) 가 아니라 심리학 용어이며, 사용자가 무의식적으로 사용하는
/// 언어 패턴에서 내재된 동기와 인지 필터(메타프로그램)를 추론한다.
///
/// 일기 단위로 1:1 캐시. [DiaryEntry.nlpInsight] 에 저장.
class NLPInsight {
  /// 1~3개. 데이터에서 매칭이 약하면 1개여도 OK.
  final List<NLPFilter> filters;

  final DateTime generatedAt;

  const NLPInsight({
    required this.filters,
    required this.generatedAt,
  });

  factory NLPInsight.fromJson(Map<String, dynamic> json) => NLPInsight(
        filters: (json['filters'] as List? ?? [])
            .map((e) => NLPFilter.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        generatedAt:
            DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
                DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'filters': filters.map((f) => f.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };
}

/// 메타프로그램 한 항목.
class NLPFilter {
  /// AI가 일기 내용에 맞춰 자유롭게 생성한 태그. 예: "과정_지향", "회피_동기".
  /// 작명 규칙(프롬프트 참조): 한국어 명사 + _ + 방향성 단어, 4~7자.
  final String tag;

  /// 한 줄 헤드라인. 예: "관계 속에서 에너지를 채우는 마음"
  final String headline;

  /// 2~3문장 본문.
  final String body;

  /// 분석 근거가 된 일기 키워드들 (1~3개).
  final List<String> evidenceKeywords;

  const NLPFilter({
    required this.tag,
    required this.headline,
    required this.body,
    required this.evidenceKeywords,
  });

  factory NLPFilter.fromJson(Map<String, dynamic> json) => NLPFilter(
        tag: (json['tag'] as String? ?? '').trim(),
        headline: (json['headline'] as String? ?? '').trim(),
        body: (json['body'] as String? ?? '').trim(),
        evidenceKeywords: (json['evidenceKeywords'] as List? ?? [])
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'headline': headline,
        'body': body,
        'evidenceKeywords': evidenceKeywords,
      };
}
