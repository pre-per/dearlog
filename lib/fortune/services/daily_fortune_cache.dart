import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_fortune.dart';

/// 하루치 "오늘의 운세"를 로컬 캐시에 저장/조회 + "오늘 본 사용자" 표시.
///
/// - 운세 자체는 사용자 단위로 다르지 않으므로 디바이스 단위로 캐시한다.
/// - "본 후 유리병이 사라지는" 동작은 동일 디바이스에서 다른 사용자가
///   로그인할 가능성을 고려해 사용자 단위(uid+date) 키로 저장.
class DailyFortuneCache {
  DailyFortuneCache._();
  static final DailyFortuneCache instance = DailyFortuneCache._();

  static const String _kFortunePrefix = 'daily_fortune_';
  static const String _kSeenPrefix = 'daily_fortune_seen_';

  /// 오늘의 [DailyFortune] 을 반환. 없으면 null.
  /// 다른 날짜의 캐시는 stale 로 간주하고 무시.
  Future<DailyFortune?> loadToday([DateTime? now]) async {
    final key = todayKey(now);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kFortunePrefix$key');
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final fortune = DailyFortune.fromJson(json);
      if (fortune.dateKey != key) return null;
      return fortune;
    } catch (_) {
      return null;
    }
  }

  /// 오늘 날짜 키로 저장.
  Future<void> saveToday(DailyFortune fortune) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_kFortunePrefix${fortune.dateKey}',
      jsonEncode(fortune.toJson()),
    );
    await _gc(prefs);
  }

  Future<void> _gc(SharedPreferences prefs) async {
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(_kFortunePrefix))
        .toList();
    if (keys.length <= 7) return;
    keys.sort();
    for (final k in keys.take(keys.length - 7)) {
      await prefs.remove(k);
    }
  }

  /// 사용자가 오늘 유리병을 열었는지(=운세를 본 적 있는지) 확인.
  /// uid 가 비어있으면 디바이스 단위로 처리 (게스트 흐름 방어).
  Future<bool> hasSeenToday(String uid, [DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_seenKey(uid));
    return stored == todayKey(now);
  }

  Future<void> markSeenToday(String uid, [DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenKey(uid), todayKey(now));
  }

  /// 디버그용 — 사용자가 오늘 본 기록을 지운다 (유리병이 다시 나타나도록).
  Future<void> clearSeen(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenKey(uid));
  }

  /// 디버그용 — 오늘자 운세 캐시도 지운다 (다음 sheet 열 때 새로 fetch).
  Future<void> clearTodayFortune([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kFortunePrefix${todayKey(now)}');
  }

  String _seenKey(String uid) =>
      '$_kSeenPrefix${uid.isEmpty ? "_anon" : uid}';
}
