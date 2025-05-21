import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/conversation.dart';
import '../../providers/live_conversation_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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

  Future<void> _toggleRecording() async {
    if (!_isSpeechAvailable) return;

    if (isRecording) {
      // 수동 중단
      await _speech.stop();
      _handleFinalSpeech();
    } else {
      // 녹음 시작
      setState(() {
        isRecording = true;
        _currentText = '';
      });

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _currentText = result.recognizedWords;
          });

          if (result.finalResult) {
            _handleFinalSpeech();
          }
        },

        listenFor: const Duration(seconds: 20), // 최대 20초 녹음
        pauseFor: const Duration(seconds: 3),
        localeId: 'ko_KR', // 한국어
      );
    }
  }

  void _handleFinalSpeech() async {
    if (_currentText.trim().isNotEmpty) {
      setState(() {
        messages.add(Message(role: 'user', content: _currentText.trim()));
        _currentText = '';
        isRecording = false;
      });
    } else {
      setState(() {
        isRecording = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    _isSpeechAvailable = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: $error'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncMessage = ref.watch(liveConversationStreamProvider);

    asyncMessage.whenData((newMessage) {
      if (!messages.contains(newMessage)) {
        setState(() {
          messages.add(newMessage);
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: const [
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
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.call_end, color: Colors.white),
              label: const Text(
                "통화 종료",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          )
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.volume_up, size: 20, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentText.isEmpty ? '말씀해보세요...' : _currentText,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 🫧 메시지 리스트
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isUser = msg.role == 'user';

                    return AnimatedOpacity(
                      opacity: 1,
                      duration: const Duration(milliseconds: 300),
                      child: Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blueAccent : Colors.grey[300],
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
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 90),
            ],
          ),

          // 🎙 마이크 버튼
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRecording ? Colors.redAccent : Colors.blueAccent,
                    boxShadow: isRecording
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
}
