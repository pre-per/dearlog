import 'dart:async';
import 'package:dearlog/call/services/conversation_backup_service.dart';
import 'package:dearlog/call/services/tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dearlog/app.dart';
import 'package:dearlog/call/providers/voice_provider.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final _textController = TextEditingController();
  
  // ✅ initState에서 초기화하기 위해 late 사용
  late final TtsService _tts;
  bool _isSpeaking = false;
  final FocusNode _inputFocus = FocusNode();
  bool _sending = false;

  bool _sessionActive = true;
  bool _startingListening = false;

  Timer? _timer;
  Duration _elapsedAccum = Duration.zero;
  DateTime? _runningSince;

  bool _isPaused = false;
  bool _isTextMode = false;

  Duration get _currentElapsed {
    if (_runningSince == null) return _elapsedAccum;
    return _elapsedAccum + DateTime.now().difference(_runningSince!);
  }

  @override
  void initState() {
    super.initState();
    
    // ✅ 선택한 목소리 가져와서 TTS 서비스 초기화
    final selectedVoice = ref.read(selectedVoiceProvider);
    _tts = TtsService(
      apiKey: RemoteConfigService().openAIApiKey,
      voice: selectedVoice,
    );
    _tts.init();
    
    _runningSince = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_runningSince != null) {
        setState(() {});
      }
    });

    _ensureSpeechAndStart();
  }

  Future<void> _ensureSpeechAndStart() async {
    final speech = ref.read(speechNotifierProvider.notifier);
    await speech.ensureInitialized();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 800));
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

  Future<void> _startListeningSafely() async {
    if (!_sessionActive || _isPaused || _isTextMode) return;
    if (_startingListening) return;

    _startingListening = true;
    try {
      final speech = ref.read(speechNotifierProvider.notifier);
      final currentState = ref.read(speechNotifierProvider);

      if (currentState.isRecording) return;

      await speech.ensureInitialized();

      bool started = false;
      for (int i = 0; i < 3; i++) {
        if (ref.read(speechNotifierProvider).isAvailable) {
          speech.enableContinuous();
          await speech.startListening(_sendText);
          started = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      if (!started) {
        debugPrint("마이크 엔진을 시작할 수 없습니다.");
      }
    } catch (e) {
      debugPrint("마이크 시작 오류: $e");
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
      await Future.delayed(const Duration(milliseconds: 60));
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _sendText(String text) async {
    if (!_sessionActive || _sending) return;

    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    _sending = true;
    try {
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

      if (reply.isNotEmpty && _sessionActive && !_isPaused && !_isTextMode) {
        setState(() => _isSpeaking = true);
        try {
          await _tts.speakAndWait(reply);
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          debugPrint("TTS 에러 발생: $e");
        } finally {
          setState(() => _isSpeaking = false);
        }
      }

      if (_sessionActive && !_isPaused && !_isTextMode) {
        await _startListeningSafely();
      }
    } finally {
      _sending = false;
    }
  }

  Future<void> _onPauseToggle() async {
    final speech = ref.read(speechNotifierProvider.notifier);
    setState(() => _isPaused = !_isPaused);

    if (_isPaused) {
      if (_runningSince != null) {
        _elapsedAccum += DateTime.now().difference(_runningSince!);
        _runningSince = null;
      }
      await speech.shutdown();
    } else {
      _runningSince = DateTime.now();
      if (!_isTextMode) {
        await _startListeningSafely();
      }
    }
  }

  Future<void> _onTextToggle() async {
    final speech = ref.read(speechNotifierProvider.notifier);

    if (!_isTextMode) {
      setState(() => _isTextMode = true);
      await speech.shutdown();
      if (!mounted) return;
      _inputFocus.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isTextMode = false);

    if (!_isPaused) {
      await _startListeningSafely();
    }
  }

  /// [DEBUG ONLY] 일기 생성 실패 상황을 시뮬레이션
  Future<void> _debugForceFailure() async {
    _sessionActive = false;
    _timer?.cancel();
    _timer = null;
    await ref.read(speechNotifierProvider.notifier).shutdown();
    await _tts.stop();

    final messages = ref.read(messageProvider);
    await ConversationBackupService.save(messages);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainScreen(snackMessage: '[DEBUG] 강제 실패 — 복구 배너를 확인하세요.'),
      ),
      (route) => false,
    );
  }

  Future<void> _onCallEnd() async {
    _sessionActive = false;
    _timer?.cancel();
    _timer = null;
    await ref.read(speechNotifierProvider.notifier).shutdown();
    await _tts.stop();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallLoadingScreen(elapsed: _currentElapsed),
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
              colorFilter: const ColorFilter.mode(Color(0x80ffffff), BlendMode.srcIn),
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
        actions: [
          if (kDebugMode)
            GestureDetector(
              onTap: _debugForceFailure,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.6)),
                ),
                child: const Text(
                  'FAIL',
                  style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)..copyWith(bottom: _bottomAreaHeight(context)),
              itemCount: messages.length,
              itemBuilder: (context, index) => MessageBubble(message: messages[index]),
            ),
          ),
          SizedBox(height: _bottomAreaHeight(context) + MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
    final shouldShow = isSessionActive && !isTextMode && !isPaused;
    final showSpeaking = shouldShow && isSpeaking;
    if (!shouldShow) return const SizedBox.shrink();

    final titleText = showSpeaking ? 'AI가 말하는 중...' : (isRecording ? '말씀하세요...' : '마이크 준비 중...');
    final guideText = showSpeaking ? '말이 끝나면 자동으로 다시 들을게요.' : (isRecording ? '지금 말한 내용이 아래에 실시간으로 표시돼요.' : '잠시만 기다려 주세요.');
    final displayText = liveText.trim().isEmpty ? (showSpeaking ? '' : '…') : liveText.trim();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusDot(active: showSpeaking ? true : isRecording),
              const SizedBox(width: 10),
              Expanded(child: Text(titleText, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 14, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(999)),
                child: Text(showSpeaking ? 'TTS' : (isRecording ? 'REC' : 'WAIT'), style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(guideText, style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12)),
          const SizedBox(height: 10),
          if (!showSpeaking)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0x12FFFFFF), borderRadius: BorderRadius.circular(14)),
              child: Text(displayText, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 14, height: 1.25)),
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
      decoration: BoxDecoration(shape: BoxShape.circle, color: active ? const Color(0xFFFFFFFF) : const Color(0x66FFFFFF)),
    );
  }
}

class _TextInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function(String) onSend;
  final VoidCallback onClose;
  const _TextInputBar({required this.controller, required this.focusNode, required this.onSend, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x22FFFFFF))),
        child: Row(
          children: [
            GestureDetector(
              onTap: onClose,
              child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.close, color: Color(0xCCFFFFFF), size: 20)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (v) async => await onSend(v),
                style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 14),
                decoration: const InputDecoration(hintText: '키보드로 입력해 보세요…', hintStyle: TextStyle(color: Color(0x80FFFFFF)), border: InputBorder.none, isDense: true),
              ),
            ),
            GestureDetector(
              onTap: () async => await onSend(controller.text),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(14)),
                child: const Text('전송', style: TextStyle(color: Color(0xE6FFFFFF), fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
