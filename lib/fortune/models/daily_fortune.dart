/// 하루치 "오늘의 운세" 한 건.
///
/// 별점은 1~5. body 는 따옴표/마크다운 없이 2~3 문장.
class DailyFortune {
  /// 운세 본문 (2~3 문장).
  final String body;

  /// 4가지 영역 별점 (1~5).
  final int money;
  final int love;
  final int work;
  final int health;

  /// 행운 색상 — 한국어 색 이름. 예: '그레이', '빨강', '골드'.
  final String luckyColor;

  /// 행운 아이템/키워드. 예: '액세서리', '이차원 코드', '스포츠 음료'.
  final String luckyItem;

  /// 운세가 만들어진 날의 로컬 날짜 키 (YYYYMMDD). 캐시 검증용.
  final String dateKey;

  const DailyFortune({
    required this.body,
    required this.money,
    required this.love,
    required this.work,
    required this.health,
    required this.luckyColor,
    required this.luckyItem,
    required this.dateKey,
  });

  Map<String, dynamic> toJson() => {
        'body': body,
        'money': money,
        'love': love,
        'work': work,
        'health': health,
        'luckyColor': luckyColor,
        'luckyItem': luckyItem,
        'dateKey': dateKey,
      };

  factory DailyFortune.fromJson(Map<String, dynamic> json) {
    int clamp(dynamic v) {
      final n = (v is num) ? v.toInt() : 3;
      if (n < 1) return 1;
      if (n > 5) return 5;
      return n;
    }

    return DailyFortune(
      body: (json['body'] as String? ?? '').trim(),
      money: clamp(json['money']),
      love: clamp(json['love']),
      work: clamp(json['work']),
      health: clamp(json['health']),
      luckyColor: (json['luckyColor'] as String? ?? '').trim(),
      luckyItem: (json['luckyItem'] as String? ?? '').trim(),
      dateKey: (json['dateKey'] as String? ?? '').trim(),
    );
  }
}

/// 오늘의 로컬 날짜 키 (YYYYMMDD).
String todayKey([DateTime? now]) {
  final n = now ?? DateTime.now();
  final m = n.month.toString().padLeft(2, '0');
  final d = n.day.toString().padLeft(2, '0');
  return '${n.year}$m$d';
}
