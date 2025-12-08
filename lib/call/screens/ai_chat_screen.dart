import 'dart:async';
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

  // ✅ 일시정지/재개 정확한 타이머를 위한 상태
  Timer? _timer;
  Duration _elapsedAccum = Duration.zero; // 누적 시간(일시정지 중에도 유지)
  DateTime? _runningSince; // 진행 중 시작 시각(null이면 멈춤)

  bool _isPaused = false; // 통화 일시정지 상태
  bool _isTextMode = false; // 글로 작성 모드

  final _textController = TextEditingController();

  // 현재 화면에 표시할 경과 시간
  Duration get _currentElapsed {
    if (_runningSince == null) return _elapsedAccum;
    return _elapsedAccum + DateTime.now().difference(_runningSince!);
  }

  @override
  void initState() {
    super.initState();

    // ▶️ 통화 시작: 러닝 시작 시각 기록
    _runningSince = DateTime.now();

    // 1초 틱으로 화면 갱신
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_runningSince != null) {
        setState(() {}); // _currentElapsed를 다시 그리기
      }
    });

    // ✅ 상시 음성 인식: 화면 진입 시 자동 시작
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final speech = ref.read(speechNotifierProvider.notifier);
      await speech.ensureInitialized(); // ⬅️ 추가
      await speech.startListening(_handleUserMessage); // ⬅️ 보장된 상태에서 시작
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _textController.dispose();
    super.dispose();
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

  Future<void> _handleUserMessage(String text) async {
    if (text.trim().isEmpty) return;
    final notifier = ref.read(messageProvider.notifier);
    notifier.addUserMessage(text);

    await notifier.getAssistantResponse();
    _scrollToBottom();

    // 응답 후 자동 재청취 (텍스트 모드 X && 일시정지 X)
    if (!_isTextMode && !_isPaused) {
      await ref
          .read(speechNotifierProvider.notifier)
          .startListening(_handleUserMessage);
      // ↳ speech_provider에 restartListening이 있다면 위 줄을 그걸로 바꿔도 OK
    }
  }

  // ⏯ 통화 멈추기/다시 시작
  Future<void> _onPauseToggle() async {
    final speech = ref.read(speechNotifierProvider.notifier);

    setState(() => _isPaused = !_isPaused);

    if (_isPaused) {
      // ⏸ 일시정지: 지금까지 흐른 구간을 누적하고, 러닝 상태 끊기
      if (_runningSince != null) {
        _elapsedAccum += DateTime.now().difference(_runningSince!);
        _runningSince = null;
      }
      await speech.stopListening();
    } else {
      // ▶️ 재개: 새 구간 시작
      _runningSince = DateTime.now();
      if (!_isTextMode) {
        await speech.startListening(_handleUserMessage);
      }
    }
  }

  // ✍️ 글로 작성하기 토글 (타이머는 그대로, 음성만 제어)
  Future<void> _onTextToggle() async {
    final speech = ref.read(speechNotifierProvider.notifier);

    setState(() => _isTextMode = !_isTextMode);

    if (_isTextMode) {
      await speech.stopListening();
    } else {
      if (!_isPaused) {
        await speech.startListening(_handleUserMessage);
      }
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await _handleUserMessage(text);
  }

  // ☎️ 통화 종료 시 저장
  Future<void> _createDiaryAndSaveToProvider() async {
    final openaiService = OpenAIService();

    try {
      final userId = ref.read(userIdProvider);
      final callId = const Uuid().v4();
      final messages = ref.read(messageProvider);

      if (userId != null) {
        final call = Call(
          callId: callId,
          timestamp: DateTime.now(),
          duration: _currentElapsed, // ✅ 정확한 경과 시간 저장
          messages: messages,
        );
        await ref.read(callRepositoryProvider).saveCall(userId, call);
      }

      final diary = await openaiService.generateDiaryFromMessages(
        messages,
        callId: callId,
      );
      ref.read(diaryListNotifierProvider.notifier).saveDiary(diary);
      ref.invalidate(diaryListProvider);
    } catch (e) {
      debugPrint('일기 생성 또는 통화 저장 실패: $e');
    }
  }

  void _onCallEnd() async {
    // 종료 시 타이머/음성 정지
    _timer?.cancel();
    ref.read(speechNotifierProvider.notifier).stopListening();

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallDoneScreen()));

    await _createDiaryAndSaveToProvider();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messageProvider);

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
              _formatDuration(_currentElapsed), // ✅ 변경됨
              style: const TextStyle(color: Color(0x80ffffff), fontFamily: 'Alumni'),
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
            // 대화 표시
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                itemCount: messages.length,
                itemBuilder:
                    (context, index) =>
                        MessageBubble(message: messages[index]),
              ),
            ),
            Spacer(),
            SizedBox(
              height: 250,
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
