import 'dart:convert';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// OpenAI TTS 기반 TtsService
/// - /v1/audio/speech 호출해서 mp3 생성
/// - just_audio로 재생
class TtsService {
  // 너 프로젝트에서 키를 가져오는 방식에 맞춰 수정
  // 예: RemoteConfigService().openAIApiKey
  final String apiKey;

  // 추천 기본값 (문서 기준)
  String model; // gpt-4o-mini-tts | tts-1 | tts-1-hd
  String voice; // marin/cedar 추천
  double speed; // 0.25 ~ 4.0 범위로 쓰는 케이스가 많음
  String responseFormat; // "mp3" 추천

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  // 간단 캐시: 같은 텍스트는 파일 재사용 (비용/속도 절약)
  Directory? _cacheDir;

  TtsService({
    required this.apiKey,
    this.model = 'gpt-4o-mini-tts',
    this.voice = 'marin',
    this.speed = 1.0,
    this.responseFormat = 'mp3',
  });

  Future<void> init() async {
    if (_initialized) return;
    _cacheDir = await _ensureCacheDir();

    // ✅ just_audio가 오디오 세션을 자동으로 관리하도록 설정
    // (재생할 때 활성화, 끝나면 비활성화)
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

  /// AiChatScreen이 쓰는 함수: 말하고 끝날 때까지 기다리기
  Future<void> speakAndWait(
      String text, {
        String? instructions,
      }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    if (!_initialized) {
      await init();
    }

    // 이미 재생 중이면 끊고 새로
    await _player.stop();

    final file = await _synthesizeToCachedFile(
      cleaned,
      instructions: instructions ?? "따뜻하고 자연스럽게, 친구에게 말하듯이.",
    );

    // ✅ just_audio에게 재생할 파일을 알려주기만 하면 됨
    // init()에서 설정했기 때문에 세션 관리는 자동으로 처리됨
    await _player.setFilePath(file.path);
    await _player.play();

    // 재생 완료까지 await
    await _player.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed);
    await _player.stop(); // completed 이후 상태 정리
  }

  // -------------------- 내부 --------------------

  Future<Directory> _ensureCacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/openai_tts_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _hashKey(String input) {
    return sha1.convert(utf8.encode(input)).toString();
  }

  Future<File> _synthesizeToCachedFile(
      String text, {
        required String instructions,
      }) async {
    final dir = _cacheDir ?? await _ensureCacheDir();

    // 캐시 키에는 모델/보이스/속도/지시까지 포함 (다르면 음성이 달라지니까)
    final cacheKey = _hashKey('$model|$voice|$speed|$responseFormat|$instructions|$text');
    final file = File('${dir.path}/$cacheKey.$responseFormat');

    if (await file.exists() && await file.length() > 0) {
      return file;
    }

    final uri = Uri.parse('https://api.openai.com/v1/audio/speech');

    final body = <String, dynamic>{
      "model": model,
      "voice": voice,
      "input": text,
      "response_format": responseFormat,
      "speed": speed,
      // gpt-4o-mini-tts에서 “톤/말투” 지시 가능
      "instructions": instructions,
    };

    final res = await http.post(
      uri,
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('OpenAI TTS 실패(${res.statusCode}): ${res.body}');
    }

    await file.writeAsBytes(res.bodyBytes, flush: true);
    return file;
  }
}
