import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing voice names backed by Supertonic 2 presets.
/// (See [kSupertonicVoiceToPreset] in supertonic_tts_engine.dart for mapping.)
const List<String> kAvailableVoices = ['alex', 'daniel', 'sarah', 'lily'];

/// Default voice for new installs.
const String kDefaultVoice = 'alex';

const String _kVoicePrefsKey = 'selected_voice';

/// Migrate any legacy or unknown voice value (e.g. 'marin' from the old
/// OpenAI-only build) to the default. Existing users won't see a confusing
/// orphaned selection on first launch after upgrade.
String _normalizeVoice(String voice) {
  return kAvailableVoices.contains(voice) ? voice : kDefaultVoice;
}

/// 사용자가 선택한 음성을 SharedPreferences 에 영속화하는 Notifier.
///
/// 변경 시 [setVoice] 사용. `state =` 직접 대입은 Notifier API 상 외부에서 막혀 있어
/// 자연스럽게 영속화 경로를 강제한다 — 호출자가 새로 추가될 때도 같은 경로를 타게.
class SelectedVoiceNotifier extends Notifier<String> {
  @override
  String build() {
    // 비동기 로드 — build 가 sync 라 default 로 시작하고 prefs 가 도착하면 갱신.
    // 첫 build 후 사용자가 음성을 보기까지 보통 prefs read 가 충분히 끝난다.
    _loadFromPrefs();
    return kDefaultVoice;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kVoicePrefsKey);
      if (saved != null && kAvailableVoices.contains(saved)) {
        state = saved;
      }
    } catch (_) {/* 실패 시 default 유지 */}
  }

  /// 새 음성으로 변경 + 즉시 영속화.
  Future<void> setVoice(String voice) async {
    final normalized = _normalizeVoice(voice);
    state = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kVoicePrefsKey, normalized);
    } catch (_) {/* 영속화 실패해도 메모리 상태는 그대로 */}
  }
}

final selectedVoiceProvider =
    NotifierProvider<SelectedVoiceNotifier, String>(SelectedVoiceNotifier.new);

/// Read-only provider that always returns a valid voice name even if a stale
/// value sneaks into the underlying state (defensive for upgrades).
final normalizedSelectedVoiceProvider = Provider<String>((ref) {
  return _normalizeVoice(ref.watch(selectedVoiceProvider));
});
