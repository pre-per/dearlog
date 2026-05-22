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

// ─────────────────────────────────────────────────
// TTS 재생 속도
// ─────────────────────────────────────────────────

/// 사용자가 고르는 TTS 재생 속도 배율. 1.0 = 기본 속도.
/// UI 슬라이더의 min/max/step 도 이 파일을 single source of truth 로 삼는다.
const double kMinSpeed = 0.5;
const double kMaxSpeed = 2.0;
const double kSpeedStep = 0.1;
const double kDefaultSpeed = 1.0;
const String _kSpeedPrefsKey = 'selected_tts_speed';

/// 슬라이더 값이 0.1 배수에 맞도록 반올림 + 범위 clamp.
double _normalizeSpeed(double s) {
  if (s.isNaN || s.isInfinite) return kDefaultSpeed;
  final stepped = (s / kSpeedStep).roundToDouble() * kSpeedStep;
  if (stepped < kMinSpeed) return kMinSpeed;
  if (stepped > kMaxSpeed) return kMaxSpeed;
  // 부동소수 오차로 1.0000000001 같은 값이 새는 걸 막기 위해 1 decimal 로 자른다.
  return double.parse(stepped.toStringAsFixed(1));
}

class SelectedSpeedNotifier extends Notifier<double> {
  @override
  double build() {
    _loadFromPrefs();
    return kDefaultSpeed;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_kSpeedPrefsKey);
      if (saved != null) state = _normalizeSpeed(saved);
    } catch (_) {/* 실패 시 default 유지 */}
  }

  Future<void> setSpeed(double speed) async {
    final normalized = _normalizeSpeed(speed);
    if (state == normalized) return;
    state = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kSpeedPrefsKey, normalized);
    } catch (_) {/* 영속화 실패해도 메모리 상태는 그대로 */}
  }
}

final selectedSpeedProvider =
    NotifierProvider<SelectedSpeedNotifier, double>(SelectedSpeedNotifier.new);
