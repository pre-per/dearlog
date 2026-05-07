import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'supertonic/supertonic_tts_engine.dart';

/// Quality (denoising steps) and speed for Supertonic synthesis.
/// Tuned per product: 5 steps balances quality/latency, 1.2× matches the
/// previous OpenAI 1.05× perceived pace given Supertonic's natural cadence.
const int _kSupertonicSteps = 5;
const double _kSupertonicSpeed = 1.2;

/// OpenAI fallback voice mapping when Supertonic fails. Picked to roughly
/// match the gender/timbre of the Supertonic preset so a fallback isn't
/// jarring mid-conversation.
const Map<String, String> _kOpenAiFallbackVoice = {
  'alex': 'onyx',     // deep male
  'daniel': 'echo',   // warm male
  'sarah': 'nova',    // warm female
  'lily': 'shimmer',  // bright female
};

/// Hybrid TTS service: Supertonic 2 (on-device, primary) with OpenAI TTS
/// as a fallback when Supertonic fails to load or synthesize.
///
/// Public API is preserved from the previous OpenAI-only implementation so
/// the streaming pipeline in ai_chat_screen.dart works unchanged:
/// - `fetchAudio(text)` → Uint8List of audio bytes (WAV or MP3)
/// - `playAudio(bytes)` → plays the bytes via just_audio
/// - `speakAndWait(text)` → fetch + play in one call
class TtsService {
  /// OpenAI API key — only consulted when falling back from Supertonic.
  final String apiKey;

  /// User-facing voice name (alex/daniel/sarah/lily). Legacy OpenAI voices
  /// (marin/onyx/...) are still accepted and route directly to OpenAI.
  String voice;

  /// OpenAI fallback parameters.
  String openAiModel;
  double openAiSpeed;
  String openAiResponseFormat;

  // Same audio session handling as before — see configureAudioSession() for
  // why we manage focus manually instead of letting just_audio do it.
  final AudioPlayer _player =
      AudioPlayer(handleAudioSessionActivation: false);
  bool _initialized = false;
  int _seq = 0;

  TtsService({
    required this.apiKey,
    this.voice = 'alex',
    this.openAiModel = 'gpt-4o-mini-tts',
    this.openAiSpeed = 1.05,
    this.openAiResponseFormat = 'mp3',
  });

  Future<void> init() async {
    if (_initialized) return;
    await _configureAudioSession();
    _initialized = true;
    // Kick off Supertonic load in the background — first synthesis still
    // awaits, but subsequent calls are instant.
    if (isSupertonicVoice(voice)) {
      // ignore: unawaited_futures
      SupertonicTtsEngine.instance.ensureLoaded().catchError((e) {
        debugPrint('[TTS] background warm-up failed: $e');
      });
    }
  }

  Future<bool> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));

    final granted = await _acquireFocusWithRetry(session);
    if (!granted) {
      debugPrint('[TTS] ❌ audio focus 획득 최종 실패 — 재생을 건너뜀');
    }
    return granted;
  }

  Future<bool> _acquireFocusWithRetry(AudioSession session) async {
    try {
      if (await session.setActive(true)) return true;
    } catch (e) {
      debugPrint('[TTS] setActive(true) 1차 예외: $e');
    }
    await Future.delayed(const Duration(milliseconds: 120));
    try {
      if (await session.setActive(true)) return true;
    } catch (e) {
      debugPrint('[TTS] setActive(true) 2차 예외: $e');
    }
    return false;
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  /// Returns audio bytes (WAV from Supertonic, or MP3 from OpenAI fallback).
  /// Caller plays them via `playAudio`. The pipeline in ai_chat_screen.dart
  /// kicks off `fetchAudio` per sentence in parallel with GPT streaming.
  Future<Uint8List> fetchAudio(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return Uint8List(0);
    if (!_initialized) await init();

    if (isSupertonicVoice(voice)) {
      try {
        return await SupertonicTtsEngine.instance.synthesizeWav(
          cleaned,
          voice: voice,
          steps: _kSupertonicSteps,
          speed: _kSupertonicSpeed,
        );
      } catch (e, st) {
        // Fall through to OpenAI on any Supertonic failure (load error,
        // inference exception, etc.). This is the entire reason we keep
        // the OpenAI path alive.
        debugPrint('[TTS] ⚠️ Supertonic failed, falling back to OpenAI: $e');
        debugPrint('$st');
        return await _fetchOpenAi(cleaned, _kOpenAiFallbackVoice[voice] ?? 'onyx');
      }
    }

    // Voice is a legacy OpenAI voice — go straight to OpenAI.
    return await _fetchOpenAi(cleaned, voice);
  }

  Future<Uint8List> _fetchOpenAi(String text, String voiceName) async {
    if (apiKey.isEmpty) {
      debugPrint('[TTS] ❌ apiKey 가 비어 있습니다 — RemoteConfig fetch 가 실패한 상태일 가능성이 높습니다.');
      throw Exception('TTS apiKey 비어 있음 (RemoteConfig fetch 실패 추정)');
    }
    // 타임아웃 + 5xx/429 1회 재시도. 텍스트 한 문장이라 30초로 충분.
    http.Response? response;
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final r = await http.post(
          Uri.parse('https://api.openai.com/v1/audio/speech'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': openAiModel,
            'voice': voiceName,
            'input': text,
            'response_format': openAiResponseFormat,
            'speed': openAiSpeed,
          }),
        ).timeout(const Duration(seconds: 30));
        if ((r.statusCode >= 500 || r.statusCode == 429) && attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 1500));
          continue;
        }
        response = r;
        break;
      } on TimeoutException {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 1500));
          continue;
        }
        throw Exception('TTS 요청 시간 초과');
      } on SocketException {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 1500));
          continue;
        }
        throw Exception('TTS 네트워크 오류');
      } on http.ClientException {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 1500));
          continue;
        }
        throw Exception('TTS 통신 오류');
      }
    }
    if (response == null) {
      throw Exception('TTS 응답 없음');
    }
    if (response.statusCode != 200) {
      debugPrint('[TTS] ❌ OpenAI ${response.statusCode}: '
          '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
      throw Exception('TTS fetch 실패(${response.statusCode})');
    }
    return response.bodyBytes;
  }

  /// Plays raw audio bytes. Detects WAV vs MP3 from the magic header so the
  /// temp file gets the right extension (some Android decoder paths sniff
  /// the extension before the magic bytes).
  Future<void> playAudio(Uint8List bytes) async {
    if (bytes.isEmpty) return;

    final ext = _detectAudioExt(bytes);
    if (kDebugMode) {
      debugPrint('[TTS] playback bytes=${bytes.length} ext=$ext');
    }

    final granted = await _configureAudioSession();
    if (!granted) return;

    await _player.stop();

    final file = await _writeTempFile(bytes, _nextFileName('playback', ext));
    try {
      await _player.setFilePath(file.path);
      final completionFuture = _player.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed)
          .timeout(const Duration(seconds: 60),
              onTimeout: () => ProcessingState.idle);
      await _player.play();
      await completionFuture;
    } catch (e, st) {
      debugPrint('[TTS] ❌ playAudio 예외: $e');
      debugPrint('[TTS] stack: $st');
      rethrow;
    } finally {
      _deleteSilently(file);
    }
  }

  /// Synthesizes [text] and plays it through to completion.
  /// [onPlaybackStart] fires once audio starts (used by preview UI to flip
  /// from "loading spinner" to "stop button").
  Future<void> speakAndWait(String text,
      {void Function()? onPlaybackStart}) async {
    final bytes = await fetchAudio(text);
    if (bytes.isEmpty) return;

    final ext = _detectAudioExt(bytes);
    if (kDebugMode) {
      final magicHex = bytes.length >= 4
          ? '${bytes[0].toRadixString(16)} ${bytes[1].toRadixString(16)} '
              '${bytes[2].toRadixString(16)} ${bytes[3].toRadixString(16)}'
          : '<too short>';
      debugPrint('[TTS] preview bytes=${bytes.length} '
          'magic=$magicHex ext=$ext');
    }

    final granted = await _configureAudioSession();
    if (!granted) return;

    await _player.stop();

    final file = await _writeTempFile(bytes, _nextFileName('preview', ext));
    try {
      await _player.setFilePath(file.path);
      final completionFuture = _player.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed)
          .timeout(const Duration(seconds: 60),
              onTimeout: () => ProcessingState.idle);
      onPlaybackStart?.call();
      await _player.play();
      await completionFuture;
      await _player.stop();
    } catch (e, st) {
      debugPrint('[TTS] ❌ play 단계 예외: $e');
      debugPrint('[TTS] stack: $st');
      rethrow;
    } finally {
      _deleteSilently(file);
    }
  }

  // ── 유틸 ──

  /// Detects WAV vs MP3 from the first few bytes. Defaults to mp3 if unsure
  /// (OpenAI fallback) since just_audio still plays WAV with .mp3 extension
  /// on iOS but Android can be picky.
  String _detectAudioExt(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 &&
        bytes[2] == 0x46 && bytes[3] == 0x46) {
      return 'wav';
    }
    return 'mp3';
  }

  String _nextFileName(String prefix, String ext) {
    _seq = (_seq + 1) & 0xFFFF;
    return 'tts_${prefix}_$_seq.$ext';
  }

  Future<File> _writeTempFile(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _deleteSilently(File file) {
    try {
      file.deleteSync();
    } catch (_) {}
  }
}
