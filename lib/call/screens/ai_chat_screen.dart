import 'dart:async';
import 'package:dearlog/call/services/tts_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';
import 'package:dearlog/app.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final _textController = TextEditingController();
  final TtsService _tts = TtsService();
  bool _isSpeaking = false;

  // ✅ 통화 세션 상태 (종료 후 재청취 금지)
  bool _sessionActive = true;

  // ✅ 중복 startListening 방지
  bool _startingListening = false;

  // ✅ 일시정지/재개 정확한 타이머를 위한 상태
  Timer? _timer;
  Duration _elapsedAccum = Duration.zero; // 누적 시간(일시정지 중에도 유지)
  DateTime? _runningSince; // 진행 중 시작 시각(null이면 멈춤)

  bool _isPaused = false; // 통화 일시정지 상태
  bool _isTextMode = false; // 글로 작성 모드

  // 현재 화면에 표시할 경과 시간
  Duration get _currentElapsed {
    if (_runningSince == null) return _elapsedAccum;
    return _elapsedAccum + DateTime.now().difference(_runningSince!);
  }

  @override
  void initState() {
    super.initState();
    _tts.init();

    // ▶️ 통화 시작: 러닝 시작 시각 기록
    _runningSince = DateTime.now();

    // 1초 틱으로 화면 갱신
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_runningSince != null) {
        setState(() {}); // _currentElapsed를 다시 그리기
      }
    });

    // ✅ 화면 진입 시 자동으로 "연속 듣기" 시작
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final speech = ref.read(speechNotifierProvider.notifier);
      await speech.ensureInitialized();
      await _startListeningSafely();
    });
  }

  @override
  void dispose() {
    _sessionActive = false;

    _timer?.cancel();
    _timer = null;

    // ✅ 화면 나갈 때 마이크 확실히 종료(연속 재시작 OFF 포함)
    ref.read(speechNotifierProvider.notifier).shutdown(); // best-effort

    _scrollController.dispose();
    _textController.dispose();
    _tts.dispose();
    super.dispose();
  }

  /// ✅ 연속 듣기 안전 시작 (조건/중복 방지)
  Future<void> _startListeningSafely() async {
    if (!_sessionActive || _isPaused || _isTextMode) return;
    if (_startingListening) return;

    _startingListening = true;
    try {
      final speech = ref.read(speechNotifierProvider.notifier);
      speech.enableContinuous(); // ✅ 연속 모드 ON
      await speech.startListening(_handleUserMessage);
    } finally {
      _startingListening = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// ✅ 사용자 메시지 처리: 여기서는 "재청취"를 직접 하지 않는다.
  /// (연속 재시작은 speech_provider의 onStatus가 담당)
  Future<void> _handleUserMessage(String text) async {
    if (!_sessionActive) return;

    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    // 사용자가 말하는 동안/후 AI 처리 들어갈 때는 듣기 정리
    final speech = ref.read(speechNotifierProvider.notifier);
    speech.disableContinuous();
    await speech.stopListening();

    final notifier = ref.read(messageProvider.notifier);
    notifier.addUserMessage(cleaned);

    // AI 응답 받기
    await notifier.getAssistantResponse();
    _scrollToBottom();

    // ✅ 마지막 assistant 메시지 텍스트 추출
    final messages = ref.read(messageProvider);
    final lastAssistant = messages.lastWhere(
          (m) => m.role == 'assistant',
      orElse: () => messages.last,
    );
    final reply = lastAssistant.content.trim();

    // ✅ TTS로 말하기
    if (reply.isNotEmpty && _sessionActive && !_isPaused && !_isTextMode) {
      _isSpeaking = true;
      try {
        await _tts.speakAndWait(reply);

        // flutter_tts는 speak()가 "바로 반환"되는 설정/플랫폼도 있어.
        // 그래서 완전 정확히 말끝까지 기다리려면 completion handler를 쓰는 편이 좋다.
        // 일단은 간단하게 "짧은 딜레이 + 재청취"로 시작 가능:
        await Future.delayed(const Duration(milliseconds: 300));
      } finally {
        _isSpeaking = false;
      }
    }

    // ✅ 말 끝나면 다시 듣기 재개
    if (_sessionActive && !_isPaused && !_isTextMode) {
      await _startListeningSafely(); // 너가 이전에 만든 안전 시작 함수
    }
  }


  /// ⏯ 통화 멈추기/다시 시작
  Future<void> _onPauseToggle() async {
    final speech = ref.read(speechNotifierProvider.notifier);

    setState(() => _isPaused = !_isPaused);

    if (_isPaused) {
      // ⏸ 일시정지: 지금까지 흐른 구간을 누적하고, 러닝 상태 끊기
      if (_runningSince != null) {
        _elapsedAccum += DateTime.now().difference(_runningSince!);
        _runningSince = null;
      }

      // ✅ 연속 OFF + 완전 정지
      await speech.shutdown();
    } else {
      // ▶️ 재개: 새 구간 시작
      _runningSince = DateTime.now();

      // ✅ 텍스트 모드가 아니면 다시 듣기 시작
      if (!_isTextMode) {
        await _startListeningSafely();
      }
    }
  }

  /// ✍️ 글로 작성하기 토글 (타이머는 그대로, 음성만 제어)
  Future<void> _onTextToggle() async {
    final speech = ref.read(speechNotifierProvider.notifier);

    setState(() => _isTextMode = !_isTextMode);

    if (_isTextMode) {
      // ✅ 텍스트 모드 진입: 마이크 완전 종료
      await speech.shutdown();
    } else {
      // ✅ 텍스트 모드 종료: 일시정지가 아니면 다시 듣기 시작
      if (!_isPaused) {
        await _startListeningSafely();
      }
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await _handleUserMessage(text);
  }

  Future<void> _createDiaryAndSaveToProvider() async {
    final openaiService = OpenAIService();

    void log(String msg) => debugPrint('[DIARY_FLOW] $msg');

    try {
      log('start');

      final userId = ref.read(userIdProvider);
      log('userId=$userId');

      final callId = const Uuid().v4();
      log('callId=$callId');

      final messages = ref.read(messageProvider);
      log('messages=${messages.length}');

      if (userId != null) {
        log('saving call...');
        final call = Call(
          callId: callId,
          timestamp: DateTime.now(),
          duration: _currentElapsed,
          messages: messages,
        );
        await ref.read(callRepositoryProvider).saveCall(userId, call);
        log('call saved');
      } else {
        log('userId null - skip call save');
      }

      log('generating diary...');
      final diary = await openaiService.generateDiaryFromMessages(
        messages,
        callId: callId,
      );
      log('diary generated id=${diary.id} imageUrls=${diary.imageUrls.length}');

      log('saving diary to firestore...');
      await ref.read(diaryRepositoryProvider).saveDiary(userId!, diary);
      log('diary saved to firestore');

      ref.invalidate(diaryListProvider);
      log('invalidate done');
    } catch (e, st) {
      debugPrint('[DIARY_FLOW][ERROR] $e\n$st');
    }
  }

  /// ✅ 통화 종료: 마이크 완전 종료 + 세션 종료 플래그
  Future<void> _onCallEnd() async {
    _sessionActive = false;

    _timer?.cancel();
    _timer = null;

    await ref.read(speechNotifierProvider.notifier).shutdown();
    await _tts.stop();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallLoadingScreen(
          elapsed: _currentElapsed, // 필요하면 넘기고
        ),
      ),
    );
  }


  String _formatDuration(Duration duration) {
    final minutes =
    duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
    duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messageProvider);
    final speechState = ref.watch(speechNotifierProvider);

    return BaseScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 40,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'asset/icons/call/timer.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                Color(0x80ffffff),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _formatDuration(_currentElapsed),
              style: const TextStyle(
                color: Color(0x80ffffff),
                fontFamily: 'Alumni',
              ),
            ),
          ],
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) =>
                    MessageBubble(message: messages[index]),
              ),
            ),

// ✅ 여기부터: 마이크 상태/실시간 텍스트 표시 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: _MicStatusPanel(
                isSessionActive: _sessionActive,
                isPaused: _isPaused,
                isTextMode: _isTextMode,
                isSpeaking: _isSpeaking,
                isRecording: speechState.isRecording,
                liveText: speechState.currentText,
              ),
            ),

            SizedBox(
              height: 150,
              width: double.infinity,
              child: CallFuncIsland(
                onPauseToggle: _onPauseToggle,
                onTextToggle: _onTextToggle,
                onCallEnd: _onCallEnd,
              ),
            ),

            const SizedBox(height: 20),

          ],
        ),
      ),
    );
  }
}

class _MicStatusPanel extends StatelessWidget {
  final bool isSessionActive;
  final bool isPaused;
  final bool isTextMode;
  final bool isSpeaking;

  final bool isRecording;
  final String liveText;

  const _MicStatusPanel({
    required this.isSessionActive,
    required this.isPaused,
    required this.isTextMode,
    required this.isSpeaking,
    required this.isRecording,
    required this.liveText,
  });

  @override
  Widget build(BuildContext context) {
    // 보여줄지 여부: 통화중 + (텍스트모드 아님) + (일시정지 아님)
    final shouldShow = isSessionActive && !isTextMode && !isPaused;

    // AI가 말하는 중이면 "듣는 중" UI 대신 "말하는 중" UI를 보여주고 싶으면 true
    final showSpeaking = shouldShow && isSpeaking;

    if (!shouldShow) {
      // 숨기되 공간은 살짝 유지하고 싶으면 SizedBox(height: 8) 같은 걸로 바꿔도 됨
      return const SizedBox.shrink();
    }

    final titleText = showSpeaking
        ? 'AI가 말하는 중...'
        : (isRecording ? '말씀하세요...' : '마이크 준비 중...');

    final guideText = showSpeaking
        ? '말이 끝나면 자동으로 다시 들을게요.'
        : (isRecording ? '지금 말한 내용이 아래에 실시간으로 표시돼요.' : '잠시만 기다려 주세요.');

    final displayText = liveText.trim().isEmpty
        ? (showSpeaking ? '' : '…')
        : liveText.trim();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF), // 투명 흰색
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 타이틀 + 상태 점
          Row(
            children: [
              _StatusDot(
                active: showSpeaking ? true : isRecording,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titleText,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 오른쪽 작은 라벨
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  showSpeaking
                      ? 'TTS'
                      : (isRecording ? 'REC' : 'WAIT'),
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            guideText,
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),

          // 실시간 인식 텍스트
          if (!showSpeaking)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0x12FFFFFF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                displayText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;
  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFFFFFFFF) : const Color(0x66FFFFFF),
      ),
    );
  }
}
