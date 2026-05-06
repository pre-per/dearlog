import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 통화 종료 후 그림일기 자동 생성 여부.
/// 기본값 ON. 사용자가 끄면 SharedPreferences에 저장되어 다음 통화에도 유지됨.
///
/// 향후 유료 기능으로 전환 시 이 값을 결제 상태와 함께 게이팅할 예정.
class IllustrationToggleNotifier extends StateNotifier<bool> {
  static const _prefsKey = 'call_illustration_enabled';

  IllustrationToggleNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_prefsKey);
    if (stored != null) state = stored;
  }

  Future<void> set(bool value) async {
    if (state == value) return;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  Future<void> toggle() => set(!state);
}

final illustrationEnabledProvider =
    StateNotifierProvider<IllustrationToggleNotifier, bool>(
  (ref) => IllustrationToggleNotifier(),
);
