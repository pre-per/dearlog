import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

import '../../core/services/openai_service.dart';
import '../../core/shared_widgets/dialog/lottie_popup_dialog.dart';
import '../../diary/providers/diary_providers.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../../call/models/conversation/message.dart';
import '../../call/models/conversation/call.dart';
import '../providers/call_provider.dart';
import '../widgets/chat_appbar.dart';
import '../widgets/loading_dialog.dart';
import '../widgets/message_bubble.dart';
import '../widgets/record_button.dart';
import '../widgets/recording_indicator.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final List<Message> messages = [];
  bool isRecording = false;

  late stt.SpeechToText _speech;
  bool _isSpeechAvailable = false;
  String _currentText = '';

  final ScrollController _scrollController = ScrollController();
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        messages.add(Message(role: 'assistant', content: '여보세요? 오늘 하루는 어땠어?'));
      });
      _startTime = DateTime.now();
    });
  }

  Future<void> _initializeSpeech() async {
    _isSpeechAvailable = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: \$status'),
      onError: (error) => debugPrint('Speech error: \$error'),
    );
  }

  Future<void> _toggleRecording() async {
    if (!_isSpeechAvailable) return;

    if (isRecording) {
      await _speech.stop();
      _handleFinalSpeech();
    } else {
      setState(() {
        isRecording = true;
        _currentText = '';
      });

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _currentText = result.recognizedWords;
          });

          if (result.finalResult) _handleFinalSpeech();
        },
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(milliseconds: 2000),
        localeId: 'ko_KR',
      );
    }
  }

  void _handleFinalSpeech() async {
    if (_currentText.trim().isEmpty) {
      setState(() => isRecording = false);
      return;
    }

    final userMessage = Message(role: 'user', content: _currentText.trim());
    setState(() {
      messages.add(userMessage);
      isRecording = false;
      _currentText = '';
      messages.add(Message(role: 'assistant', content: '__loading__'));
    });

    try {
      final openaiService = OpenAIService();
      final chatResponse = await openaiService.getChatResponse([...messages]);

      setState(() {
        messages.removeWhere(
          (msg) => msg.role == 'assistant' && msg.content == '__loading__',
        );
        messages.add(chatResponse.message);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() {
        messages.removeWhere(
          (msg) => msg.role == 'assistant' && msg.content == '__loading__',
        );
        messages.add(
          Message(role: 'assistant', content: '죄송해요. 지금은 응답할 수 없어요. 에러: \$e'),
        );
      });
    }
  }

  Future<void> _handleDiaryCreationToProvider() async {
    final openaiService = OpenAIService();

    try {
      final userId = ref.read(userIdProvider);
      final callId = const Uuid().v4();

      // 통화 저장
      if (userId != null && _startTime != null) {
        final call = Call(
          callId: callId,
          timestamp: DateTime.now(),
          duration: DateTime.now().difference(_startTime!),
          messages: messages,
        );
        await ref.read(callRepositoryProvider).saveCall(userId, call);
      }

      // 일기 생성 및 저장
      final diary = await openaiService.generateDiaryFromMessages(
        messages,
        callId: callId,
      );
      ref.read(diaryListNotifierProvider.notifier).saveDiary(diary);
      ref.invalidate(userProvider);
    } catch (e) {
      debugPrint('일기 생성 또는 통화 저장 실패: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBar(onEndCall: () => _showPopupDialog(context)),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              const Divider(height: 1),
              if (isRecording) RecordingIndicator(currentText: _currentText),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return MessageBubble(message: messages[index]);
                  },
                ),
              ),
              const SizedBox(height: 90),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: RecordButton(
                isRecording: isRecording,
                onTap: _toggleRecording,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPopupDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => LottiePopupDialog(
            lottieAsset: 'asset/lottie/check.json',
            messageText: '디어로그와 통화에 성공했어요🥳',
            confirmButtonText: '확인',
            onConfirm: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const LoadingDialog(),
              );

              await _handleDiaryCreationToProvider();

              if (context.mounted) Navigator.of(context).pop(); // loading 닫기
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
    );
  }
}
