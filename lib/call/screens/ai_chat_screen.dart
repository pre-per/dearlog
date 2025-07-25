import 'dart:async';

import 'package:dearlog/call/widgets/call_func_island.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/openai_service.dart';
import '../../core/shared_widgets/dialog/lottie_popup_dialog.dart';
import '../../diary/providers/diary_providers.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../../call/models/conversation/call.dart';
import '../providers/call_provider.dart';
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

  DateTime? _startTime;
  late Timer _timer;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() {
        _elapsedTime = DateTime.now().difference(_startTime!);
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _handleUserMessage(String text) async {
    if (text.trim().isEmpty) return;
    final notifier = ref.read(messageProvider.notifier);
    notifier.addUserMessage(text);
    await notifier.getAssistantResponse();

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

  Future<void> _createDiaryAndSaveToProvider() async {
    final openaiService = OpenAIService();

    try {
      final userId = ref.read(userIdProvider);
      final callId = const Uuid().v4();
      final messages = ref.read(messageProvider);

      if (userId != null && _startTime != null) {
        final call = Call(
          callId: callId,
          timestamp: DateTime.now(),
          duration: DateTime.now().difference(_startTime!),
          messages: messages,
        );
        await ref.read(callRepositoryProvider).saveCall(userId, call);
      }

      final diary = await openaiService.generateDiaryFromMessages(
        messages,
        callId: callId,
      );
      ref.read(diaryListNotifierProvider.notifier).saveDiary(diary);
      ref.invalidate(userProvider);
    } catch (e) {
      debugPrint('일기 생성 또는 통화 저장 실패: $e');
    }
  }

  void _showPopupDialog(BuildContext context) {
    _timer.cancel();
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
    final speechNotifier = ref.read(speechNotifierProvider.notifier);
    final messages = ref.watch(messageProvider);

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
            Text(_formatDuration(_elapsedTime), style: const TextStyle(color: Colors.black)),
          ],
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.green[50],
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return MessageBubble(message: messages[index]);
                  },
                ),
              ),
            ),
            SizedBox(
              height: 60,
              child: speechState.isRecording
                  ? RecordingIndicator(currentText: speechState.currentText)
                  : null,
            ),
            SizedBox(
              height: 300,
              width: double.infinity,
              child: CallFuncIsland(
                onTap1: () {},
                onTap2: () {},
                onTap3: () => speechNotifier.toggleRecording(_handleUserMessage),
                onCallEnd: () => _showPopupDialog(context),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
