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

/// Quality (denoising steps) and base speed for Supertonic synthesis.
/// Tuned per product: 5 steps balances quality/latency, 1.2× matches the
/// previous OpenAI 1.05× perceived pace given Supertonic's natural cadence.
///
/// 사용자가 [TtsService.speedMultiplier] 로 추가 배율을 주면 이 베이스 값에
/// 곱해서 "원하는 effective speed" 가 결정된다. 단, Supertonic 의 duration
/// predictor 는 학습 분포(≈1.0~1.2x) 를 크게 벗어나면 짧은 음절을 통째로
/// 건너뛰는 현상이 있어, 모델 단의 speed 는 [_kSupertonicModelSpeedCap] 으로
/// clamp 하고 그 이상의 배율은 just_audio 의 setSpeed (네이티브 피치 보정
/// time-stretching) 로 후처리한다. 결과적으로 사용자가 보는 effective speed 는
/// 동일하지만 음절 누락 없이 자연스럽게 빨라진다.
const int _kSupertonicSteps = 5;
const double _kSupertonicBaseSpeed = 1.2;

/// Supertonic 모델 단에서 허용하는 speed 의 안전 상한. 이 값까지는 모델이
/// 학습 분포 안이라 음절 누락 없이 합성 가능. 더 빠른 속도는 player 의
/// setSpeed 로 처리한다.
const double _kSupertonicModelSpeedCap = 1.3;

/// OpenAI TTS 기본 속도. Supertonic 과 perceived pace 를 맞추기 위해 1.05.
const double _kOpenAiBaseSpeed = 1.05;

/// OpenAI TTS API 가 허용하는 speed 상한.
const double _kOpenAiSpeedMax = 4.0;

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
  String openAiResponseFormat;

  /// 사용자가 슬라이더로 고른 배속. 1.0 = 기본. 베이스 속도(Supertonic 1.2 /
  /// OpenAI 1.05) 에 곱해져 실제 합성 속도가 된다.
  /// 다이얼로그가 슬라이더로 즉시 갱신할 수 있도록 mutable.
  double speedMultiplier;

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
    this.openAiResponseFormat = 'mp3',
    this.speedMultiplier = 1.0,
  });

  /// 사용자가 듣게 될 최종 Supertonic effective speed (= 모델 × player).
  /// UI/디버그 용도. 합성에는 [_supertonicModelSpeed] / [_supertonicPlayerSpeed] 를 사용.
  double get _effectiveSupertonicSpeed => _kSupertonicBaseSpeed * speedMultiplier;

  /// Supertonic 합성에 실제로 넘기는 모델 단 speed. 안전 상한으로 clamp.
  double get _supertonicModelSpeed {
    final effective = _effectiveSupertonicSpeed;
    return effective > _kSupertonicModelSpeedCap
        ? _kSupertonicModelSpeedCap
        : effective;
  }

  /// 모델 speed 로 처리하지 못한 나머지 배율 — player.setSpeed 로 적용.
  /// 모델 speed ≥ effective speed 면 1.0 (player 보정 없음).
  double get _supertonicPlayerSpeed {
    final effective = _effectiveSupertonicSpeed;
    final model = _supertonicModelSpeed;
    return effective > model ? effective / model : 1.0;
  }

  /// Effective OpenAI speed after applying user multiplier. OpenAI 의 speed 는
  /// 0.25~4.0 안에서 자체 피치 보정해 처리하므로 그대로 넘기되 상한만 clamp.
  double get _effectiveOpenAiSpeed {
    final raw = _kOpenAiBaseSpeed * speedMultiplier;
    return raw > _kOpenAiSpeedMax ? _kOpenAiSpeedMax : raw;
  }

  Future<void> init() async {
    if (_initialized) return;
    // 의도적으로 여기서 _configureAudioSession() 을 호출하지 않는다.
    //   AiChatScreen.initState 는 _tts.init() 과 _ensureSpeechAndStart() 를
    //   거의 동시에 호출하는데, init 시점에 setActive(true) 가 audio focus 를
    //   잡아버리면 iOS 실기기에서 STT 의 _speech.listen() 이 silently 시작에
    //   실패해 "마이크 대기중..." 에서 더 이상 진행되지 않는 사례가 보고됐다.
    //   Audio session 은 playAudio() 진입 시마다 다시 configure 되므로,
    //   이 시점에 미리 잡아둘 필요가 없다.
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
      // 같은 세션에서 supertonic 로드가 실패한 적이 있다면(저장공간 부족
      // 으로 모델 캐시가 손상되는 케이스 포함) 매번 다시 시도하지 말고 곧장
      // OpenAI 로 — 매 문장마다 디스크 IO 비용을 다시 치르면 fallback 응답이
      // 늦어져서 통화가 얼어붙은 것처럼 보인다.
      if (SupertonicTtsEngine.instance.hasGivenUp) {
        return await _fetchOpenAi(
            cleaned, _kOpenAiFallbackVoice[voice] ?? 'onyx');
      }
      try {
        return await SupertonicTtsEngine.instance.synthesizeWav(
          cleaned,
          voice: voice,
          steps: _kSupertonicSteps,
          speed: _supertonicModelSpeed,
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
            'speed': _effectiveOpenAiSpeed,
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
  ///
  /// Supertonic 합성 결과(WAV)는 모델 단 speed cap 으로 인해 사용자 배율을
  /// 다 못 채웠을 수 있어 player.setSpeed 로 남은 배율을 보정한다. OpenAI 는
  /// 이미 API 단에서 피치 보정해 합성되므로 player 는 1.0 으로 둔다.
  Future<void> playAudio(Uint8List bytes) async {
    if (bytes.isEmpty) return;

    final ext = _detectAudioExt(bytes);
    final playerSpeed = ext == 'wav' ? _supertonicPlayerSpeed : 1.0;
    if (kDebugMode) {
      debugPrint('[TTS] playback bytes=${bytes.length} ext=$ext '
          'playerSpeed=${playerSpeed.toStringAsFixed(3)}');
    }

    final granted = await _configureAudioSession();
    if (!granted) return;

    await _player.stop();

    final file = await _writeTempFile(bytes, _nextFileName('playback', ext));
    try {
      await _player.setFilePath(file.path);
      // setSpeed 는 just_audio 가 native time-stretching (iOS=AVAudio,
      // Android=PlaybackParams) 으로 피치 보정해 처리. 1.0 일 땐 no-op.
      await _player.setSpeed(playerSpeed);
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

    final playerSpeed = ext == 'wav' ? _supertonicPlayerSpeed : 1.0;
    final file = await _writeTempFile(bytes, _nextFileName('preview', ext));
    try {
      await _player.setFilePath(file.path);
      await _player.setSpeed(playerSpeed);
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
