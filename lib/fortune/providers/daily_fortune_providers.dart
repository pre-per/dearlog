import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/services/openai_service.dart';
import '../../app/di/providers.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../models/daily_fortune.dart';
import '../services/daily_fortune_cache.dart';

/// 오늘의 운세. 캐시 있으면 그것 사용, 없으면 OpenAI 호출.
/// 같은 날 다시 watch 해도 캐시에서 즉시 반환.
final dailyFortuneProvider =
    FutureProvider.autoDispose<DailyFortune>((ref) async {
  final cached = await DailyFortuneCache.instance.loadToday();
  if (cached != null) return cached;

  final service = ref.read(openAIServiceProvider);
  final now = DateTime.now();
  final fortune = await service.generateDailyFortune(now);
  await DailyFortuneCache.instance.saveToday(fortune);
  return fortune;
});

/// "오늘 유리병을 본 적이 있는지" 상태. 본 후에는 홈 화면에서 유리병이 사라지게.
class FortuneSeenNotifier extends StateNotifier<bool> {
  FortuneSeenNotifier(this._uid) : super(false) {
    _load();
  }
  final String? _uid;

  Future<void> _load() async {
    if (_uid == null || _uid.isEmpty) {
      state = false;
      return;
    }
    final seen = await DailyFortuneCache.instance.hasSeenToday(_uid);
    if (mounted) state = seen;
  }

  Future<void> markSeen() async {
    if (_uid == null || _uid.isEmpty) {
      state = true;
      return;
    }
    await DailyFortuneCache.instance.markSeenToday(_uid);
    if (mounted) state = true;
  }

  /// 디버그용 — 오늘 본 기록을 지워 유리병이 다시 떠다니게 한다.
  Future<void> resetSeen() async {
    if (_uid != null && _uid.isNotEmpty) {
      await DailyFortuneCache.instance.clearSeen(_uid);
    }
    if (mounted) state = false;
  }
}

final fortuneSeenProvider =
    StateNotifierProvider<FortuneSeenNotifier, bool>((ref) {
  final uid = ref.watch(userIdProvider);
  return FortuneSeenNotifier(uid);
});

/// 유리병이 홈에 떠있을지 여부. 로그인되어 있고 오늘 아직 보지 않았으면 표시.
/// 운세 fetch 자체는 lazy — 유리병 클릭 시점에 `dailyFortuneProvider` 가
/// 처음 trigger 되어도 무방.
final shouldShowBottleProvider = Provider<bool>((ref) {
  final uid = ref.watch(userIdProvider);
  if (uid == null || uid.isEmpty) return false;
  final seen = ref.watch(fortuneSeenProvider);
  if (seen) return false;
  return true;
});
