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

  /// 딜레이 최소화를 위해 파일 저장 없이 메모리 스트림으로 재생
  Future<void> speakAndWait(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;
    if (!_initialized) await init();

    await _player.stop();

    final uri = Uri.parse('https://api.openai.com/v1/audio/speech');
    final response = await http.post(
      uri,
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": model,
        "voice": voice,
        "input": cleaned,
        "response_format": responseFormat,
        "speed": speed,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI TTS 실패(${response.statusCode}): ${response.body}');
    }

    // 메모리에서 바로 재생
    await _player.setAudioSource(MyCustomSource(response.bodyBytes));
    await _player.play();

    // 포지션이 끝에 도달하는 즉시 정지 (지연 시간 없음)
    await _player.positionStream.firstWhere(
      (position) => _player.duration != null && position >= _player.duration!,
      orElse: () => Duration.zero,
    );
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
