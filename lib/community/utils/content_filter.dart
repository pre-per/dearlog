/// 커뮤니티 게시물/댓글의 금칙어 검사.
///
/// App Store 심사 가이드라인 1.2 — UGC 앱은 부적절 콘텐츠를 필터링하는 수단이
/// 필요하다. 완전한 자동 모더레이션이 아니라 명백한 욕설/혐오 표현의 1차 차단이
/// 목적이고, 나머지는 신고(운영 검토) + 차단으로 보완한다.
/// 일기 톤의 정상 문장이 걸리지 않도록 목록은 보수적으로 유지한다.
class ContentFilter {
  ContentFilter._();

  static const List<String> _banned = [
    // 욕설
    '시발', '씨발', '씨빨', '시팔', '씨팔', 'ㅅㅂ', 'ㅆㅂ',
    '병신', '븅신', 'ㅂㅅ', '지랄', 'ㅈㄹ', '좆', '썅',
    '개새끼', '개색기', '개색끼', '새끼야', '니애미', '니에미', '느금마', '엠창',
    // 혐오/성적
    '창녀', '걸레년', '한남충', '김치녀', '보지년', '자지', '강간',
    'fuck', 'shit', 'bitch', 'asshole',
  ];

  /// 금칙어가 있으면 해당 단어를, 없으면 null 을 반환한다.
  /// "시 발" 같은 공백/기호 우회를 막기 위해 정규화 후 검사한다.
  static String? findBannedWord(String text) {
    final normalized =
        text.toLowerCase().replaceAll(RegExp(r'[\s.,\-_*!?~]+'), '');
    for (final w in _banned) {
      if (normalized.contains(w)) return w;
    }
    return null;
  }
}
