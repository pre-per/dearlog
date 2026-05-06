import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User-facing voice names backed by Supertonic 2 presets.
/// (See [kSupertonicVoiceToPreset] in supertonic_tts_engine.dart for mapping.)
const List<String> kAvailableVoices = ['alex', 'daniel', 'sarah', 'lily'];

/// Default voice for new installs.
const String kDefaultVoice = 'alex';

/// Migrate any legacy or unknown voice value (e.g. 'marin' from the old
/// OpenAI-only build) to the default. Existing users won't see a confusing
/// orphaned selection on first launch after upgrade.
String _normalizeVoice(String voice) {
  return kAvailableVoices.contains(voice) ? voice : kDefaultVoice;
}

final selectedVoiceProvider = StateProvider<String>((ref) => kDefaultVoice);

/// Read-only provider that always returns a valid voice name even if a stale
/// value sneaks into the underlying state (defensive for upgrades).
final normalizedSelectedVoiceProvider = Provider<String>((ref) {
  return _normalizeVoice(ref.watch(selectedVoiceProvider));
});
