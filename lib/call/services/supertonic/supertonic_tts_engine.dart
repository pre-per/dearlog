import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'supertonic_helper.dart';

/// Maps app-facing voice names to Supertonic 2 preset codes.
///
/// Why these specific presets:
/// - Alex (M1): lively/upbeat male — energetic friend
/// - Daniel (M5): warm/soothing male — calm friend, audiobook-like
/// - Sarah (F1): calm female with slightly low tone — grounded friend
/// - Lily (F2): bright/cheerful female — upbeat friend
const Map<String, String> kSupertonicVoiceToPreset = {
  'alex': 'M1',
  'daniel': 'M5',
  'sarah': 'F1',
  'lily': 'F2',
};

bool isSupertonicVoice(String voice) =>
    kSupertonicVoiceToPreset.containsKey(voice.toLowerCase());

/// Supertonic 2 inference engine — singleton.
///
/// Loading the 4 ONNX models is ~10–30 s on first cold start (256MB to read
/// from app bundle and copy into the cache directory). After the first load
/// it stays resident, and synthesis runs on-device with no network call.
///
/// Designed to be created per-app, not per-screen. Construct lazily with
/// `instance` so screens that never trigger TTS don't pay the model load.
class SupertonicTtsEngine {
  SupertonicTtsEngine._();
  static final SupertonicTtsEngine _instance = SupertonicTtsEngine._();
  static SupertonicTtsEngine get instance => _instance;

  static const String _onnxDir = 'asset/supertonic/onnx';
  static const String _voiceStylesDir = 'asset/supertonic/voice_styles';

  TextToSpeech? _tts;
  Completer<void>? _loadCompleter;
  Object? _loadError;
  // Once a load attempt fails (commonly: low storage, partial bundle copy on
  // first launch), every subsequent `synthesizeWav` would otherwise re-enter
  // `loadTextToSpeech` and pay the full disk-IO cost before giving up. That
  // delays the OpenAI fallback per sentence and makes the call feel frozen.
  // Latch the failure so callers fail fast and route to the fallback path.
  bool _hasGivenUp = false;
  final Map<String, Style> _styleCache = {};

  // ONNX sessions hold mutable state during inference — running two synthesis
  // calls concurrently against the same session crashes or returns garbage.
  // The chat streaming pipeline kicks off `fetchAudio` for multiple sentences
  // in parallel, so we serialize synthesis here. Output is still pipelined
  // because each call still resolves as soon as its turn finishes.
  Future<void>? _synthesisLock;

  /// True once the ONNX models are loaded and ready for synthesis.
  bool get isReady => _tts != null;

  /// True if a previous load attempt failed and we've stopped retrying for
  /// this app session. Callers (e.g., `TtsService`) check this to skip
  /// straight to the OpenAI fallback without waiting on another disk hit.
  bool get hasGivenUp => _hasGivenUp;

  /// Kick off the model load in the background. Safe to call multiple times.
  /// Returns a future that completes when the engine is ready (or fails).
  Future<void> ensureLoaded() async {
    if (_tts != null) return;
    if (_hasGivenUp) {
      // Already failed once this session — fail fast so the caller can fall
      // back without paying disk IO again.
      throw _loadError ?? StateError('Supertonic engine previously failed to load');
    }
    if (_loadCompleter != null) {
      // Another caller is already loading — wait for it.
      return _loadCompleter!.future;
    }
    final completer = Completer<void>();
    _loadCompleter = completer;
    try {
      _tts = await loadTextToSpeech(_onnxDir);
      _loadError = null;
      completer.complete();
    } catch (e, st) {
      _loadError = e;
      _hasGivenUp = true;
      // Print survives release builds — these errors are critical to diagnose
      // when bundle assets fail to extract on a real device.
      debugPrint('[Supertonic] ❌ load failed (giving up for session): $e\n$st');
      completer.completeError(e, st);
    } finally {
      _loadCompleter = null;
    }
  }

  Future<Style> _getStyle(String preset) async {
    final cached = _styleCache[preset];
    if (cached != null) return cached;
    final style = await loadVoiceStyle(['$_voiceStylesDir/$preset.json']);
    _styleCache[preset] = style;
    return style;
  }

  /// Synthesize WAV audio bytes for [text] using the [voice] (Alex/Daniel/...)
  /// at [steps] denoising steps and [speed] speed multiplier.
  ///
  /// Throws if the voice is not a Supertonic voice or if model load failed.
  Future<Uint8List> synthesizeWav(
    String text, {
    required String voice,
    String lang = 'ko',
    int steps = 5,
    double speed = 1.2,
  }) async {
    final preset = kSupertonicVoiceToPreset[voice.toLowerCase()];
    if (preset == null) {
      throw ArgumentError('Voice "$voice" is not a Supertonic voice');
    }
    await ensureLoaded();
    final tts = _tts;
    if (tts == null) {
      throw StateError('Supertonic engine failed to load: $_loadError');
    }
    final style = await _getStyle(preset);

    // Wait for any in-flight synthesis to drain before starting our own.
    // Swallow errors from prior calls — they're already surfaced to their
    // caller; we just need the session free.
    final prev = _synthesisLock;
    final completer = Completer<void>();
    _synthesisLock = completer.future;
    if (prev != null) {
      try { await prev; } catch (_) {}
    }

    try {
      final result = await tts.call(text, lang, style, steps, speed: speed);
      final wav = (result['wav'] as List).cast<double>();
      if (kDebugMode) {
        final dur = (result['duration'] as List).cast<double>().first;
        debugPrint('[Supertonic] synthesized ${wav.length} samples '
            '(${dur.toStringAsFixed(2)}s) @ ${tts.sampleRate}Hz '
            'voice=$voice/$preset steps=$steps speed=$speed');
      }
      return encodeWavBytes(wav, tts.sampleRate);
    } finally {
      completer.complete();
      // Clear only if no one queued behind us — otherwise the next caller
      // owns the lock chain.
      if (identical(_synthesisLock, completer.future)) {
        _synthesisLock = null;
      }
    }
  }
}
