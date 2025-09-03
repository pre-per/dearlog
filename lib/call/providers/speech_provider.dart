// speech_provider.dart
import 'dart:async'; // ✅ 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

final speechNotifierProvider =
StateNotifierProvider<SpeechNotifier, SpeechState>(
      (ref) => SpeechNotifier(),
);

class SpeechState {
  final bool isRecording;
  final bool isAvailable;
  final String currentText;
  SpeechState({
    required this.isRecording,
    required this.isAvailable,
    required this.currentText,
  });
  SpeechState copyWith({
    bool? isRecording,
    bool? isAvailable,
    String? currentText,
  }) =>
      SpeechState(
        isRecording: isRecording ?? this.isRecording,
        isAvailable: isAvailable ?? this.isAvailable,
        currentText: currentText ?? this.currentText,
      );
  factory SpeechState.initial() =>
      SpeechState(isRecording: false, isAvailable: false, currentText: '');
}

class SpeechNotifier extends StateNotifier<SpeechState> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  // ✅ 초기화 완료 대기용
  final Completer<void> _initCompleter = Completer<void>();

  // 마지막 onFinal 콜백(자동 재시작에 사용)
  Future<void> Function(String result)? _lastOnFinal;

  SpeechNotifier() : super(SpeechState.initial()) {
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final ok = await _speech.initialize(
      onStatus: (s) async {
        // print('Speech status: $s');
        if (s == 'done' || s == 'notListening') {
          state = state.copyWith(isRecording: false, currentText: '');
          // ✅ 자동 재시작 (초기화/권한 OK이고 현재 듣는 중이 아닐 때)
          if (state.isAvailable) {
            await Future.delayed(const Duration(milliseconds: 300));
            if (!_speech.isListening && _lastOnFinal != null) {
              await startListening(_lastOnFinal!);
            }
          }
        }
      },
      onError: (e) {
        // print('Speech error: $e');
        state = state.copyWith(isRecording: false);
      },
    );

    state = state.copyWith(isAvailable: ok);
    if (!_initCompleter.isCompleted) _initCompleter.complete(); // ✅ 초기화 완료 통지
  }

  /// ✅ 외부에서 초기화가 끝날 때까지 기다릴 수 있게 제공
  Future<void> ensureInitialized() => _initCompleter.future;

  Future<void> startListening(Future<void> Function(String) onFinal) async {
    // ✅ 초기화 보장: 아직이면 대기
    if (!_initCompleter.isCompleted) {
      await ensureInitialized();
    }
    if (!state.isAvailable || state.isRecording) return;

    _lastOnFinal = onFinal; // 자동 재시작을 위해 콜백 저장
    state = state.copyWith(isRecording: true, currentText: '');

    await _speech.listen(
      onResult: (result) async {
        final text = result.recognizedWords;
        state = state.copyWith(currentText: text);
        if (result.finalResult) {
          try {
            await stopListening();
          } finally {
            await onFinal(text.trim());
          }
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'ko_KR',
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    try {
      await _speech.cancel();
    } catch (_) {}
    state = state.copyWith(isRecording: false, currentText: '');
  }
}
