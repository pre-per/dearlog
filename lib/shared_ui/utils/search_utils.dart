
// Korean Util Functions
const _CHOSEONG = [
  "ㄱ","ㄲ","ㄴ","ㄷ","ㄸ","ㄹ",
  "ㅁ","ㅂ","ㅃ","ㅅ","ㅆ","ㅇ",
  "ㅈ","ㅉ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"
];

/// 문자열을 초성 문자열로 변환 (예: "평범하다" -> "ㅍㅂㅎㄷ")
String toChoseong(String input) {
  final sb = StringBuffer();
  for (var rune in input.runes) {
    if (rune >= 0xAC00 && rune <= 0xD7A3) {
      final uniVal = rune - 0xAC00;
      final cho = uniVal ~/ (21 * 28);
      sb.write(_CHOSEONG[cho]);
    } else {
      sb.write(String.fromCharCode(rune)); // 한글 외 문자는 그대로
    }
  }
  return sb.toString();
}


/// 공백/구분자/한글 날짜 단위(년월일) 제거 + 소문자
String normalizeForSearch(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\.\-_/:\\]+'), '')   // 공백/.,-_/:\ 제거
      .replaceAll(RegExp(r'[년월일]'), '');        // 한글 날짜 단위 제거
}

/// DateTime → 다양한 검색 토큰 (구분자 제거된 숫자 비교용)
List<String> buildDateTokens(DateTime dt) {
  final y  = dt.year;
  final yy = (y % 100).toString().padLeft(2, '0');
  final m  = dt.month;
  final d  = dt.day;
  final mm = m.toString().padLeft(2, '0');
  final dd = d.toString().padLeft(2, '0');

  return <String>[
    '$y$mm$dd',     // 20240901
    '$yy$mm$dd',    // 240901
    '$mm$dd',       // 0901
    '$m$d',         // 91 (한 자리 달/일도 커버)
    '$y$m$d',       // 202491
  ];
}

bool entryMatchesQuery({
  required String queryRaw,
  required String title,
  required String content,
  required DateTime? date,
  String? emotion, // ✅ 추가
}) {
  final q = normalizeForSearch(queryRaw);
  if (q.isEmpty) return true;

  // 1) 일반 문자열 매칭
  final normTitle   = normalizeForSearch(title);
  final normContent = normalizeForSearch(content);
  final normalMatch = normTitle.contains(q) || normContent.contains(q);

  // ✅ 감정 문자열 매칭 추가
  final normEmotion = normalizeForSearch(emotion ?? '');
  final emotionMatch = normEmotion.isNotEmpty && normEmotion.contains(q);

  // 2) 초성 매칭
  final choTitle   = normalizeForSearch(toChoseong(title));
  final choContent = normalizeForSearch(toChoseong(content));
  final chosungMatch = choTitle.contains(q) || choContent.contains(q);

  // 3) 날짜 매칭
  bool dateMatch = false;
  if (date != null) {
    final tokens = buildDateTokens(date).map(normalizeForSearch);
    dateMatch = tokens.any((t) => t.contains(q) || q.contains(t));
  }

  return normalMatch || emotionMatch || chosungMatch || dateMatch;
}

