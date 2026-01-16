import 'dart:async';
import 'package:dearlog/call/services/tts_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dearlog/app.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final _textController = TextEditingController();
  final TtsService _tts = TtsService(apiKey: RemoteConfigService().openAIApiKey);
  bool _isSpeaking = false;
  final FocusNode _inputFocus = FocusNode();
  bool _sending = false; // 중복 전송 방지용(선택)

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
    _inputFocus.dispose();

    _timer?.cancel();
    _timer = null;

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
      await speech.startListening(_sendText);
    } finally {
      _startingListening = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );

      // ✅ 레이아웃/키보드 변화로 maxScrollExtent가 또 바뀌는 경우 대비
      await Future.delayed(const Duration(milliseconds: 60));
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }


  Future<void> _sendText(String text) async {
    if (!_sessionActive) return;
    if (_sending) return;

    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    _sending = true;
    try {
      // 음성 모드였다면 안전하게 정리 (텍스트모드에서도 shutdown 되어있어서 문제 없음)
      final speech = ref.read(speechNotifierProvider.notifier);
      speech.disableContinuous();
      await speech.stopListening();

      final notifier = ref.read(messageProvider.notifier);
      notifier.addUserMessage(cleaned);
      _scrollToBottom();

      await notifier.getAssistantResponse();
      _scrollToBottom();

      final messages = ref.read(messageProvider);
      final lastAssistant = messages.lastWhere(
        (m) => m.role == 'assistant' && m.content != '__loading__',
        orElse: () => messages.last,
      );
      final reply = lastAssistant.content.trim();

      // 텍스트 모드에서도 TTS를 할지 여부는 선택
      if (reply.isNotEmpty && _sessionActive && !_isPaused && !_isTextMode) {
        _isSpeaking = true;
        try {
          await _tts.speakAndWait(reply);
          await Future.delayed(const Duration(milliseconds: 300));
        } finally {
          _isSpeaking = false;
        }
      }

      // 음성 모드라면 다시 듣기 재개
      if (_sessionActive && !_isPaused && !_isTextMode) {
        await _startListeningSafely();
      }
    } finally {
      _sending = false;
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

  Future<void> _onTextToggle() async {
    final speech = ref.read(speechNotifierProvider.notifier);

    // 텍스트 모드로 전환
    if (!_isTextMode) {
      setState(() => _isTextMode = true);

      // 음성 완전 종료
      await speech.shutdown();

      if (!mounted) return;
      // 키보드 올리기
      _inputFocus.requestFocus();
      return;
    }

    // 텍스트 모드 종료 -> 음성 모드 복귀
    FocusScope.of(context).unfocus();
    setState(() => _isTextMode = false);

    if (!_isPaused) {
      await _startListeningSafely();
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
        builder:
            (_) => CallLoadingScreen(
              elapsed: _currentElapsed, // 필요하면 넘기고
            ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
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
              width: 22,
              height: 22,
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
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)..copyWith(bottom: _bottomAreaHeight(context)),
              itemCount: messages.length,
              itemBuilder:
                  (context, index) => MessageBubble(message: messages[index]),
            ),
          ),
          SizedBox(height: _bottomAreaHeight(context) + MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ 텍스트모드면 입력바, 아니면 마이크 패널
              if (_isTextMode)
                _TextInputBar(
                  controller: _textController,
                  focusNode: _inputFocus,
                  onSend: (v) async {
                    await _sendText(v);
                    _textController.clear();
                  },
                  onClose: _onTextToggle,
                )
              else
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
                  isTextMode: _isTextMode,
                  isPaused: _isPaused,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  double _bottomAreaHeight(BuildContext context) {
    // 대충 값: CallFuncIsland(150) + 여백(12) + MicPanel(~90) or InputBar(~64)
    final extra = _isTextMode ? 80.0 : 120.0;
    return 150 + 12 + extra + MediaQuery.of(context).padding.bottom;
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

    final titleText =
        showSpeaking
            ? 'AI가 말하는 중...'
            : (isRecording ? '말씀하세요...' : '마이크 준비 중...');

    final guideText =
        showSpeaking
            ? '말이 끝나면 자동으로 다시 들을게요.'
            : (isRecording ? '지금 말한 내용이 아래에 실시간으로 표시돼요.' : '잠시만 기다려 주세요.');

    final displayText =
        liveText.trim().isEmpty ? (showSpeaking ? '' : '…') : liveText.trim();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              _StatusDot(active: showSpeaking ? true : isRecording),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  showSpeaking ? 'TTS' : (isRecording ? 'REC' : 'WAIT'),
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
          const SizedBox(height: 4),

          Text(
            guideText,
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
          ),
          const SizedBox(height: 10),

          // 실시간 인식 텍스트
          if (!showSpeaking)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

class _TextInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function(String) onSend;
  final VoidCallback onClose;

  const _TextInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Row(
          children: [
            // 닫기(입력 종료) 버튼
            GestureDetector(
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.close, color: Color(0xCCFFFFFF), size: 20),
              ),
            ),
            const SizedBox(width: 6),

            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (v) async {
                  await onSend(v);
                },
                style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '키보드로 입력해 보세요…',
                  hintStyle: TextStyle(color: Color(0x80FFFFFF)),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),

            GestureDetector(
              onTap: () async {
                await onSend(controller.text);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '전송',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
