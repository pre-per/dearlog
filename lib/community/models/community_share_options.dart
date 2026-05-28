/// 일기를 커뮤니티에 공유할 때 어떤 정보를 포함할지 토글하는 옵션 묶음.
///
/// "사진으로 공유" 의 [DiaryShareOptions] 와 같은 패턴을 따른다 — 각 항목별 bool
/// 토글, 화면에서 OFF 된 섹션은 게시물에서 빠진다.
///
/// 토글이 OFF 면 해당 필드는 빈 값(빈 문자열/빈 리스트) 으로 게시된다 —
/// 사용자가 토글을 끄고 직접 다른 내용으로 채우는 흐름도 자연스럽게 지원한다.
class CommunityShareOptions {
  /// 제목 노출 여부. OFF 면 입력 필드도 숨김 & post.title = ''.
  final bool includeTitle;

  /// 본문 노출 여부. OFF 면 입력 필드도 숨김 & post.content = ''.
  final bool includeContent;

  /// 그림일기 이미지(들) 노출. OFF 면 post.imageUrls = []. 게시물 이미지 미복사로
  /// Storage 비용 절감 효과까지.
  final bool includeImages;

  /// 감정 라벨/행성 아이콘 노출. OFF 면 post.emotion = '' — 피드 헤더의
  /// 행성 아이콘이 사라진다.
  final bool includeEmotion;

  /// 일기 작성 날짜 노출. OFF 면 post.diaryDate 가 게시 시각으로 대체되어
  /// "yyyy.MM.dd 작성" 표시가 작성일을 드러내지 않는다.
  final bool includeDate;

  /// NLP 인지 필터 인사이트 노출. OFF 면 본문 끝에 NLP 블록을 붙이지 않는다.
  final bool includeNlpInsight;

  const CommunityShareOptions({
    required this.includeTitle,
    required this.includeContent,
    required this.includeImages,
    required this.includeEmotion,
    required this.includeDate,
    required this.includeNlpInsight,
  });

  /// 일기 데이터 가용성에 맞춘 초기 토글값. 데이터가 없는 항목은 OFF 로 시작.
  factory CommunityShareOptions.initial({
    required bool hasImages,
    required bool hasEmotion,
    required bool hasNlpInsight,
  }) {
    return CommunityShareOptions(
      includeTitle: true,
      includeContent: true,
      includeImages: hasImages,
      includeEmotion: hasEmotion,
      includeDate: true,
      // NLP 인사이트는 정보량이 많아 기본 OFF — 사용자가 의식적으로 켜는 흐름.
      includeNlpInsight: false,
    );
  }

  CommunityShareOptions copyWith({
    bool? includeTitle,
    bool? includeContent,
    bool? includeImages,
    bool? includeEmotion,
    bool? includeDate,
    bool? includeNlpInsight,
  }) {
    return CommunityShareOptions(
      includeTitle: includeTitle ?? this.includeTitle,
      includeContent: includeContent ?? this.includeContent,
      includeImages: includeImages ?? this.includeImages,
      includeEmotion: includeEmotion ?? this.includeEmotion,
      includeDate: includeDate ?? this.includeDate,
      includeNlpInsight: includeNlpInsight ?? this.includeNlpInsight,
    );
  }
}
