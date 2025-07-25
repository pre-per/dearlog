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
  }) {
    return SpeechState(
      isRecording: isRecording ?? this.isRecording,
      isAvailable: isAvailable ?? this.isAvailable,
      currentText: currentText ?? this.currentText,
    );
  }

  factory SpeechState.initial() => SpeechState(
    isRecording: false,
    isAvailable: false,
    currentText: '',
  );
}

class SpeechNotifier extends StateNotifier<SpeechState> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  SpeechNotifier() : super(SpeechState.initial()) {
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) => print("Speech status: $status"),
      onError: (error) => print("Speech error: $error"),
    );
    state = state.copyWith(isAvailable: available);
  }

  Future<void> toggleRecording(Function(String result) onFinal) async {
    if (!state.isAvailable) return;

    if (state.isRecording) {
      await _speech.stop();
      onFinal(state.currentText.trim());
      state = state.copyWith(isRecording: false, currentText: '');
    } else {
      state = state.copyWith(isRecording: true, currentText: '');

      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          state = state.copyWith(currentText: text);

          if (result.finalResult) {
            toggleRecording(onFinal); // 종료 처리
          }
        },
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(milliseconds: 2000),
        localeId: 'ko_KR',
      );
    }
  }
}
