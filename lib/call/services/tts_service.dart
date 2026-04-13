import 'dart:convert';
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

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
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _initialized = true;
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

    await _player.stop();
    await _player.setAudioSource(MyCustomSource(bytes));

    // setAudioSource 이후에 구독해야 Android ExoPlayer의 idle→loading 전환이
    // completionFuture를 조기 완료시키지 않는다.
    final completionFuture = _player.processingStateStream
        .firstWhere((s) => s == ProcessingState.completed)
        .timeout(const Duration(seconds: 60), onTimeout: () => ProcessingState.idle);

    await _player.play();
    await completionFuture;
  }

  /// 미리보기용 — fetch + play를 한 번에 수행
  /// [onPlaybackStart]: 오디오 다운로드 완료 후 재생 시작 직전에 호출됨
  Future<void> speakAndWait(String text, {void Function()? onPlaybackStart}) async {
    final bytes = await fetchAudio(text);
    if (bytes.isEmpty) return;

    await _player.stop();
    await _player.setAudioSource(MyCustomSource(bytes));

    final completionFuture = _player.processingStateStream
        .firstWhere((s) => s == ProcessingState.completed)
        .timeout(const Duration(seconds: 60), onTimeout: () => ProcessingState.idle);

    onPlaybackStart?.call();
    await _player.play();
    await completionFuture;
    await _player.stop();
  }
}

// JustAudio 커스텀 스트림 소스
class MyCustomSource extends StreamAudioSource {
  final Uint8List bytes;
  MyCustomSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end != null ? end - (start ?? 0) : bytes.length - (start ?? 0),
      offset: start ?? 0,
      stream: Stream.value(bytes.sublist(start ?? 0, end)),
      contentType: 'audio/mpeg',
    );
  }
}
