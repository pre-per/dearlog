import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Completer<void>? _speakCompleter;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      _speakCompleter?.complete();
      _speakCompleter = null;
    });

    _tts.setErrorHandler((msg) {
      _speakCompleter?.complete();
      _speakCompleter = null;
    });

    _tts.setCancelHandler(() {
      _speakCompleter?.complete();
      _speakCompleter = null;
    });
  }

  Future<void> speakAndWait(String text) async {
    await init();
    final t = text.trim();
    if (t.isEmpty) return;

    await _tts.stop();
    _speakCompleter = Completer<void>();
    await _tts.speak(t);

    // 완료까지 대기
    await _speakCompleter!.future;
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
