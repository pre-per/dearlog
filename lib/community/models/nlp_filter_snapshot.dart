/// CommunityPost 에 동결 저장되는 NLP 인지 필터 — 카드/상세에 칩+헤드라인을
/// 한 줄 단위로 렌더링하기 위한 최소 정보만 담는다.
///
/// 원본 [NLPFilter] 의 body/evidenceKeywords 는 본문량이 많고 게시물 미감과
/// 어울리지 않아 생략한다. 게시 시점 스냅샷이라 원본 일기의 NLP 가 재분석되어도
/// 게시물의 표시값은 그대로 유지된다.
class NlpFilterSnapshot {
  final String tag;
  final String headline;

  const NlpFilterSnapshot({
    required this.tag,
    required this.headline,
  });

  factory NlpFilterSnapshot.fromJson(Map<String, dynamic> json) {
    return NlpFilterSnapshot(
      tag: (json['tag'] as String? ?? '').trim(),
      headline: (json['headline'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'headline': headline,
      };
}
