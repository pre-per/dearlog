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

  bool _submittedThisSession = false;

  // =========================
  // ✅ 무음(텍스트 변화 없음) 자동 제출 로직
  // =========================
  static const Duration _silenceThreshold = Duration(seconds: 1, milliseconds: 700);

  Timer? _silenceTimer;
  String _latestText = '';
  bool _submitting = false;

  SpeechNotifier() : super(SpeechState.initial()) {
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final ok = await _speech.initialize(
      onStatus: (s) async {
        // done / notListening = 세션 종료됨
        if (s == 'done' || s == 'notListening') {
          _cancelSilenceTimer();
          _latestText = '';
          state = state.copyWith(isRecording: false, currentText: '');

          // ✅ 연속 모드일 때만 자동 재시작
          if (_continuous && state.isAvailable) {
            await Future.delayed(const Duration(milliseconds: 250));

            if (_continuous && !_speech.isListening && _lastOnFinal != null) {
              await startListening(_lastOnFinal!);
            }
          }
        }
      },
      onError: (e) async {
        _cancelSilenceTimer();
        state = state.copyWith(isRecording: false);

        // 에러가 나도 연속 모드면 재시도
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

  bool get isContinuousEnabled => _continuous;

  // =========================
  // ✅ (추가) 무음 타이머 유틸
  // =========================
  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  void _restartSilenceTimer() {
    _cancelSilenceTimer();

    // 2초 뒤에 "여전히 텍스트 변화가 없으면" 제출
    _silenceTimer = Timer(_silenceThreshold, () async {
      // 이미 제출 중이거나, 듣는 중이 아니면 무시
      if (_submitting) return;
      if (!_speech.isListening) return;
      if (!state.isRecording) return;

      final text = _latestText.trim();
      if (text.isEmpty) return;

      await _submitLatestText(text);
    });
  }

  Future<void> _submitLatestText(String text) async {
    if (_submitting) return;
    if (_lastOnFinal == null) return;
    if (_submittedThisSession) return;

    _submittedThisSession = true;
    _submitting = true;
    try {
      // ✅ 현재 세션 종료(그러면 onStatus에서 연속이면 재시작됨)
      await _speech.stop();

      // UI 정리
      state = state.copyWith(currentText: '');

      // ✅ 최종 제출 콜백 호출
      await _lastOnFinal!(text);
    } finally {
      _latestText = '';
      _cancelSilenceTimer();
      _submitting = false;
    }
  }

  /// ✅ "듣기 시작"
  Future<void> startListening(Future<void> Function(String) onFinal) async {
    if (!_initCompleter.isCompleted) {
      await ensureInitialized();
    }
    if (!state.isAvailable) return;

    // 이미 듣고 있으면 중복 방지
    if (_speech.isListening || state.isRecording) return;

    _lastOnFinal = onFinal;

    // 상태 초기화
    _submittedThisSession = false;
    _latestText = '';
    _submitting = false;
    _cancelSilenceTimer();

    state = state.copyWith(isRecording: true, currentText: '');

    await _speech.listen(
      onResult: (result) async {
        final text = result.recognizedWords.trim();

        // 공백은 무시
        if (text.isEmpty) return;

        // ✅ 텍스트가 "실제로 바뀌었을 때만" 갱신 + 타이머 리셋
        if (text != _latestText) {
          _latestText = text;
          state = state.copyWith(currentText: text);

          // ✅ 마지막 텍스트 변화 시점으로부터 2초 무변화면 자동 제출
          _restartSilenceTimer();
        }

        // (옵션) finalResult가 오면 더 빠르게 제출해도 됨
        // iOS 실기기에선 final이 잘 안 오는 경우가 있어서,
        // 이건 "있으면 빨리 제출" 정도의 보너스 처리.
        if (result.finalResult) {
          _cancelSilenceTimer();
          if (!_submittedThisSession) {
            await _submitLatestText(_latestText.trim());
          }
        }
      },

      // ✅ 끊김 최소화 세팅(그대로 유지)
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(minutes: 5),

      partialResults: true,
      localeId: 'ko_KR',
      listenMode: stt.ListenMode.dictation,
    );
  }

  /// ✅ "완전 정지" (연속 재시작도 막으려면 disableContinuous 먼저 호출)
  Future<void> stopListening() async {
    _cancelSilenceTimer();
    _latestText = '';
    _submitting = false;

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
