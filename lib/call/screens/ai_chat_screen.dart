import 'dart:async';

import 'package:dearlog/call/widgets/call_func_island.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/di/providers.dart';
import '../../ai/services/openai_service.dart';
import '../../shared_ui/widgets/dialog/lottie_popup_dialog.dart';
import '../../diary/providers/diary_providers.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../../call/models/conversation/call.dart';
import '../providers/speech_provider.dart';
import '../providers/message_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/recording_indicator.dart';
import '../widgets/loading_dialog.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final ScrollController _scrollController = ScrollController();

  // ✅ 일시정지/재개 정확한 타이머를 위한 상태
  Timer? _timer;
  Duration _elapsedAccum = Duration.zero;   // 누적 시간(일시정지 중에도 유지)
  DateTime? _runningSince;                  // 진행 중 시작 시각(null이면 멈춤)

  bool _isPaused = false;     // 통화 일시정지 상태
  bool _isTextMode = false;   // 글로 작성 모드

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
      await speech.ensureInitialized();                  // ⬅️ 추가
      await speech.startListening(_handleUserMessage);   // ⬅️ 보장된 상태에서 시작
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
      await ref.read(speechNotifierProvider.notifier)
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

  void _showPopupDialog(BuildContext context) {
    // 종료 시 타이머/음성 정지
    _timer?.cancel();
    ref.read(speechNotifierProvider.notifier).stopListening();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LottiePopupDialog(
        lottieAsset: 'asset/lottie/check.json',
        messageText: '디어로그와 통화에 성공했어요🥳',
        confirmButtonText: '확인',
        onConfirm: () async {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const LoadingDialog(),
          );

          await _createDiaryAndSaveToProvider();

          if (context.mounted) Navigator.of(context).pop();
          if (context.mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
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
    final speechState = ref.watch(speechNotifierProvider);
    final messages = ref.watch(messageProvider);
    final showIndicator = !_isTextMode && !_isPaused && speechState.isRecording;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 40,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_outlined, color: Colors.black, size: 18),
            const SizedBox(width: 6),
            Text(
              _formatDuration(_currentElapsed), // ✅ 변경됨
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.green[50],
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // 대화 표시
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) => MessageBubble(message: messages[index]),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 녹음 중 인디케이터: 텍스트 모드 X & 일시정지 X & 녹음 중만 표시
              Visibility(
                visible: showIndicator,
                maintainState: false,
                maintainSize: false,
                maintainAnimation: false,
                child: SizedBox(
                  height: 60,
                  child: RecordingIndicator(currentText: speechState.currentText),
                ),
              ),

              // ✅ 텍스트 모드 입력창(한 줄 고정)
              if (_isTextMode)
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendTextMessage(),
                          decoration: const InputDecoration(
                            hintText: '메시지를 입력하세요',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendTextMessage,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // 기능 버튼(녹음 버튼 제거)
              SizedBox(
                height: 300,
                width: double.infinity,
                child: CallFuncIsland(
                  onPauseToggle: _onPauseToggle,
                  onTextToggle: _onTextToggle,
                  onCallEnd: () => _showPopupDialog(context),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
