import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// OpenAI TTS 기반 TtsService (스트리밍 최적화)
class TtsService {
  final String apiKey;
  String model;
  String voice;
  double speed;
  String responseFormat;

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  TtsService({
    required this.apiKey,
    this.model = 'gpt-4o-mini-tts',
    this.voice = 'marin', // 외부 주입 시 변경됨
    this.speed = 1.05,
    this.responseFormat = 'mp3',
  });

  Future<void> init() async {
    if (_initialized) return;
    await _configureAudioSession();
    _initialized = true;
  }

  /// 오디오 세션을 스피커 출력용으로 설정
  /// speech_to_text가 voiceCommunication(이어피스)으로 변경하므로,
  /// TTS 재생 전에 다시 media(스피커)로 전환해야 함
  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      // iOS: playAndRecord + defaultToSpeaker → 마이크/스피커 동시 사용
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      // Android: media usage → 스피커로 출력
      // (voiceCommunication은 이어피스로 라우팅되므로 사용 불가)
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  /// HTTP 요청만 수행 — 오디오 바이트 반환 (재생 안 함)
  /// 파이프라인에서 미리 패치할 때 사용
  Future<Uint8List> fetchAudio(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return Uint8List(0);
    if (!_initialized) await init();

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/audio/speech'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'voice': voice,
        'input': cleaned,
        'response_format': responseFormat,
        'speed': speed,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('TTS fetch 실패(${response.statusCode}): ${response.body}');
    }
    return response.bodyBytes;
  }

  /// 바이트를 받아 재생 완료까지 대기
  /// 파이프라인 플레이어 루프에서 사용
  Future<void> playAudio(Uint8List bytes) async {
    if (bytes.isEmpty) return;

    // speech_to_text가 voiceCommunication으로 세션을 바꿨을 수 있으므로
    // 매 재생 전에 스피커 출력으로 재설정
    await _configureAudioSession();
    await _player.stop();

    // Android: StreamAudioSource의 localhost 프록시 대신 임시 파일 사용
    // 일부 기기에서 cleartext 차단으로 프록시 연결 실패하는 문제 우회
    final file = await _writeTempFile(bytes, 'tts_playback.mp3');

    try {
      await _player.setFilePath(file.path);

      final completionFuture = _player.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed)
          .timeout(const Duration(seconds: 60),
              onTimeout: () => ProcessingState.idle);

      await _player.play();
      await completionFuture;
    } finally {
      _deleteSilently(file);
    }
  }

  /// 미리보기용 — fetch + play를 한 번에 수행
  /// [onPlaybackStart]: 오디오 다운로드 완료 후 재생 시작 직전에 호출됨
  Future<void> speakAndWait(String text,
      {void Function()? onPlaybackStart}) async {
    final bytes = await fetchAudio(text);
    if (bytes.isEmpty) return;

    await _configureAudioSession();
    await _player.stop();

    final file = await _writeTempFile(bytes, 'tts_preview.mp3');

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
    } finally {
      _deleteSilently(file);
    }
  }

  // ── 유틸 ──

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
