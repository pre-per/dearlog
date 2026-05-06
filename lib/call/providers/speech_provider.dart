// speech_provider.dart
import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
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

  // ✅ 자동 재시작 중복 방지 락 (onStatus / onError가 동시에 재시작 시도하는 race 차단)
  bool _isRestarting = false;

  // ✅ permanent 에러 누적 카운터 — N회 누적 시 연속 모드 OFF (무한 루프 방지)
  int _consecutivePermanentErrors = 0;
  static const int _maxConsecutivePermanentErrors = 3;

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
    debugPrint('[SPEECH] _initializeSpeech: 시작');
    bool ok = false;
    try {
      ok = await _speech.initialize(
        debugLogging: true,
        onStatus: (s) async {
          debugPrint('[SPEECH] onStatus: "$s" (continuous=$_continuous, isAvailable=${state.isAvailable}, isListening=${_speech.isListening})');
          // done / notListening = 세션 종료됨
          if (s == 'done' || s == 'notListening') {
            // ✅ 오디오 세션 비활성화 — fire-and-forget 하면 안 됨!
            // await 안 하면 TTS의 setActive(true)와 race가 발생해서
            // TTS가 방금 획득한 focus를 이 setActive(false)가 즉시 abandon해버림.
            // 그러면 just_audio가 silently 재생을 포기 → "됐다 안 됐다" 증상.
            try {
              final session = await AudioSession.instance;
              await session.setActive(false);
            } catch (e) {
              debugPrint('[SPEECH] setActive(false) 실패: $e');
            }

            _cancelSilenceTimer();
            _latestText = '';
            state = state.copyWith(isRecording: false, currentText: '');

            // ✅ 자동 재시작은 여기서만 (onError에서는 더 이상 안 함 — 중복/race 방지)
            // _isRestarting 락으로 동시 재시작 호출 차단
            if (_continuous && state.isAvailable && !_isRestarting) {
              _isRestarting = true;
              try {
                await Future.delayed(const Duration(milliseconds: 250));
                if (_continuous && !_speech.isListening && _lastOnFinal != null) {
                  debugPrint('[SPEECH] onStatus: 연속 모드 → 자동 재시작');
                  await startListening(_lastOnFinal!);
                }
              } finally {
                _isRestarting = false;
              }
            }
          }
        },
        onError: (e) async {
          debugPrint('[SPEECH] onError: ${e.errorMsg} (permanent=${e.permanent}, continuous=$_continuous, perm누적=$_consecutivePermanentErrors)');
          // ✅ 오디오 세션 비활성화 — race 방지를 위해 반드시 await
          try {
            final session = await AudioSession.instance;
            await session.setActive(false);
          } catch (err) {
            debugPrint('[SPEECH] onError setActive(false) 실패: $err');
          }

          _cancelSilenceTimer();
          state = state.copyWith(isRecording: false);

          // ✅ permanent 에러 누적 시 연속 모드 OFF — 무한 재시작 루프 차단
          if (e.permanent) {
            _consecutivePermanentErrors++;
            if (_consecutivePermanentErrors >= _maxConsecutivePermanentErrors) {
              debugPrint('[SPEECH] onError: permanent 에러 ${_consecutivePermanentErrors}회 누적 → 연속 모드 OFF (재시도 중단)');
              _continuous = false;
            }
          }

          // ✅ 재시작 로직은 onStatus('done')에서 일원화 처리.
          //    여기서 재시작 안 함 — race condition 방지.
        },
      );
      debugPrint('[SPEECH] _speech.initialize() 결과: ok=$ok');
    } catch (e, st) {
      debugPrint('[SPEECH] _speech.initialize() 예외: $e\n$st');
    }

    state = state.copyWith(isAvailable: ok);
    debugPrint('[SPEECH] _initializeSpeech: 완료 (isAvailable=$ok)');
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  Future<void> ensureInitialized() => _initCompleter.future;

  /// ✅ 통화 시작 시 호출: 자동 재시작 ON
  void enableContinuous() {
    _continuous = true;
    // 명시적으로 다시 켜는 시점이면 permanent 에러 카운터 리셋
    _consecutivePermanentErrors = 0;
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
    debugPrint('[SPEECH] startListening: 호출됨 (initCompleted=${_initCompleter.isCompleted}, isAvailable=${state.isAvailable}, isListening=${_speech.isListening}, isRecording=${state.isRecording})');
    if (!_initCompleter.isCompleted) {
      debugPrint('[SPEECH] startListening: ensureInitialized() 대기');
      await ensureInitialized();
    }
    if (!state.isAvailable) {
      debugPrint('[SPEECH] startListening: ⚠️ isAvailable=false → 조기 반환');
      return;
    }

    // ✅ 엔진의 isListening이 진실. state.isRecording은 UI용 미러.
    //    엔진이 진짜로 듣는 중이면 중복 방지하고 반환.
    if (_speech.isListening) {
      debugPrint('[SPEECH] startListening: ⚠️ 엔진이 이미 듣는 중 → 조기 반환');
      return;
    }
    // ✅ state desync 보정: state.isRecording=true인데 엔진은 안 듣고 있다면
    //    이전 세션이 비정상 종료된 것 — 보정만 하고 진행.
    if (state.isRecording) {
      debugPrint('[SPEECH] startListening: state desync 감지 (isRecording=true, isListening=false) → 보정 후 진행');
      state = state.copyWith(isRecording: false);
    }

    // ✅ 오디오 세션 설정 및 활성화
    debugPrint('[SPEECH] startListening: AudioSession 설정 시작');
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.speech());
      await session.setActive(true);
      debugPrint('[SPEECH] startListening: AudioSession 활성화 완료');
    } catch (e, st) {
      debugPrint('[SPEECH] startListening: AudioSession 설정 실패: $e\n$st');
    }

    _lastOnFinal = onFinal;

    // 상태 초기화
    _submittedThisSession = false;
    _latestText = '';
    _submitting = false;
    _cancelSilenceTimer();

    state = state.copyWith(isRecording: true, currentText: '');
    debugPrint('[SPEECH] startListening: state.isRecording=true 로 전환, _speech.listen() 호출');

    try {
      await _speech.listen(
        onResult: (result) async {
          final text = result.recognizedWords.trim();

          // 공백은 무시
          if (text.isEmpty) return;

          // ✅ 실제 음성 인식 성공 → permanent 에러 카운터 리셋
          //    (간헐적 permanent 에러가 누적되어 연속 모드가 OFF되는 걸 방지)
          _consecutivePermanentErrors = 0;

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
            debugPrint('[SPEECH] onResult: finalResult=true, text="${_latestText.trim()}"');
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
      debugPrint('[SPEECH] startListening: _speech.listen() 반환됨 (isListening=${_speech.isListening})');
    } catch (e, st) {
      debugPrint('[SPEECH] startListening: _speech.listen() 예외: $e\n$st');
      // listen() 실패 시 UI 상태도 되돌리기
      state = state.copyWith(isRecording: false);
    }
  }

  /// ✅ "완전 정지" (연속 재시작도 막으려면 disableContinuous 먼저 호출)
  Future<void> stopListening() async {
    _cancelSilenceTimer();
    _latestText = '';
    _submitting = false;

    state = state.copyWith(isRecording: false, currentText: '');

    try {
      await _speech.stop(); // 이 호출이 onStatus -> setActive(false)를 트리거합니다.
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
