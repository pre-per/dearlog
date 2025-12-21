// speech_provider.dart
import 'dart:async';
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

  factory SpeechState.initial() =>
      SpeechState(isRecording: false, isAvailable: false, currentText: '');
}

class SpeechNotifier extends StateNotifier<SpeechState> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  final Completer<void> _initCompleter = Completer<void>();

  // 연속 듣기(자동 재시작) ON/OFF
  bool _continuous = false;

  // 마지막 onFinal 콜백(연속 재시작에 사용)
  Future<void> Function(String result)? _lastOnFinal;

  SpeechNotifier() : super(SpeechState.initial()) {
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final ok = await _speech.initialize(
      onStatus: (s) async {
        // done / notListening = 세션 종료됨
        if (s == 'done' || s == 'notListening') {
          state = state.copyWith(isRecording: false, currentText: '');

          // ✅ 연속 모드일 때만 자동 재시작
          if (_continuous && state.isAvailable) {
            await Future.delayed(const Duration(milliseconds: 250));

            // 이미 듣는 중이 아니고, 콜백이 있고, 연속 모드 유지 중이면 재시작
            if (_continuous && !_speech.isListening && _lastOnFinal != null) {
              await startListening(_lastOnFinal!);
            }
          }
        }
      },
      onError: (e) async {
        state = state.copyWith(isRecording: false);

        // 에러가 나도 연속 모드면 재시도(너무 잦으면 루프 될 수 있어 약간 딜레이)
        if (_continuous && state.isAvailable) {
          await Future.delayed(const Duration(milliseconds: 400));
          if (_continuous && !_speech.isListening && _lastOnFinal != null) {
            await startListening(_lastOnFinal!);
          }
        }
      },
    );

    state = state.copyWith(isAvailable: ok);
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  Future<void> ensureInitialized() => _initCompleter.future;

  /// ✅ 통화 시작 시 호출: 자동 재시작 ON
  void enableContinuous() {
    _continuous = true;
  }

  /// ✅ 통화 종료/텍스트모드/일시정지 시 호출: 자동 재시작 OFF
  void disableContinuous() {
    _continuous = false;
  }

  /// ✅ 외부에서 연속 상태 확인하고 싶을 때
  bool get isContinuousEnabled => _continuous;

  /// ✅ "듣기 시작"
  /// - 연속 모드일 때도 여기서 세션 1회 시작
  /// - 세션이 끝나면 onStatus에서 자동 재시작
  Future<void> startListening(Future<void> Function(String) onFinal) async {
    if (!_initCompleter.isCompleted) {
      await ensureInitialized();
    }
    if (!state.isAvailable) return;
    if (_speech.isListening || state.isRecording) return;

    _lastOnFinal = onFinal;
    state = state.copyWith(isRecording: true, currentText: '');

    await _speech.listen(
      onResult: (result) async {
        final text = result.recognizedWords;
        state = state.copyWith(currentText: text);

        if (result.finalResult) {
          // ✅ "항상 켜져있게" 하려면 여기서 stop/cancel을 매번 하지 않는 게 좋음
          // finalResult가 왔을 때 콜백만 넘기고, 계속 듣기는 onStatus 재시작에 맡김
          await onFinal(text.trim());
          state = state.copyWith(currentText: '');
        }
      },

      // ✅ 끊김 최소화 세팅
      // listenFor를 길게 두면(플랫폼 제한까지) "항상 켜져있음"에 가장 가까움.
      // 너무 길어서 문제가 생기면 60~120초로 조절해도 됨.
      listenFor: const Duration(minutes: 5),

      // ✅ 무음으로 인한 자동 종료를 최대한 줄이기
      // pauseFor가 짧으면 "말 안 하면 빨리 종료" → onStatus 재시작 루프가 빈번해짐.
      // 길게(혹은 null) 두는 게 유리.
      pauseFor: const Duration(minutes: 5),

      partialResults: true,
      localeId: 'ko_KR',
      listenMode: stt.ListenMode.dictation,
    );
  }

  /// ✅ "완전 정지" (연속 재시작도 막으려면 disableContinuous 먼저 호출)
  Future<void> stopListening() async {
    state = state.copyWith(isRecording: false, currentText: '');

    try {
      await _speech.stop();
    } catch (_) {}
    try {
      await _speech.cancel();
    } catch (_) {}
  }

  /// ✅ 종료 시 안전하게 완전 종료(연속 OFF + stop)
  Future<void> shutdown() async {
    disableContinuous();
    _lastOnFinal = null;
    await stopListening();
  }
}
