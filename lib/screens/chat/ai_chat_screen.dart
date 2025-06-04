import 'package:dearlog/screens/diary/diary_detail_screen.dart';
import 'package:dearlog/widget/dialog/popup_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../models/conversation/message.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../providers/diary/diary_providers.dart';
import '../../services/openai_service.dart';

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

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        messages.add(Message(role: 'assistant', content: '여보세요? 오늘 하루는 어땠어?'));
      });
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
        messages.add(
          Message(
            role: 'system',
            content: '[이번 응답 토큰 사용량: ${chatResponse.totalTokens} tokens]',
          ),
        );
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
      final diary = await openaiService.generateDiaryFromMessages(messages);
      ref.read(generatedDiaryProvider.notifier).state = diary;
    } catch (e) {
      debugPrint('일기 생성 실패: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: const [
            SizedBox(width: 15),
            CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage("asset/image/kitty.png"),
            ),
            SizedBox(width: 12),
            Text(
              "디어로그",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showPopupDialog(context),
              icon: const Icon(Icons.call_end, color: Colors.white),
              label: const Text(
                "통화 종료",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              const Divider(height: 1),
              if (isRecording)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.volume_up,
                          size: 20,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentText.isEmpty ? '말씀해보세요...' : _currentText,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isUser = msg.role == 'user';

                    if (msg.role == 'assistant' &&
                        msg.content == '__loading__') {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SizedBox(
                            width: 80,
                            height: 60,
                            child: Lottie.asset(
                              'asset/lottie/loading.json',
                              height: 70,
                              width: 55,
                            ),
                          ),
                        ),
                      );
                    }

                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blueAccent : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          msg.content,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          softWrap: true,
                        ),
                      ),
                    );
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
              child: GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRecording ? Colors.redAccent : Colors.blueAccent,
                    boxShadow:
                        isRecording
                            ? [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.6),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ]
                            : [],
                  ),
                  child: const Icon(Icons.mic, size: 36, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPopupDialog(BuildContext context) => showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => PopupDialog(
          lottieAsset: 'asset/lottie/check.json',
          messageText: '디어로그와 통화에 성공했어요🥳',
          confirmButtonText: '확인',
          onConfirm: () async {
            await _handleDiaryCreationToProvider(); // 먼저 일기 생성

            if (!mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst); // 그 후 pop
          },
        ),
  );
}
