import 'dart:ui';

import 'package:dearlog/app.dart';
import 'package:uuid/uuid.dart';

class CallLoadingScreen extends ConsumerStatefulWidget {
  final Duration elapsed;

  const CallLoadingScreen({
    super.key,
    required this.elapsed,
  });


  @override
  ConsumerState<CallLoadingScreen> createState() => _CallLoadingScreenState();
}

class _CallLoadingScreenState extends ConsumerState<CallLoadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    void log(String msg) => debugPrint('[CALL_LOADING] $msg');

    try {
      final openaiService = OpenAIService();

      final userId = ref.read(userIdProvider);
      final callId = const Uuid().v4();
      final messages = ref.read(messageProvider);

      log('userId=$userId callId=$callId messages=${messages.length}');

      if (userId != null) {
        log('saving call...');
        final call = Call(
          callId: callId,
          timestamp: DateTime.now(),
          duration: widget.elapsed,
          messages: messages,
        );
        await ref.read(callRepositoryProvider).saveCall(userId, call);
        log('call saved');
      }

      log('generating diary...');
      final diary =
      await openaiService.generateDiaryFromMessages(messages, callId: callId);
      log('diary generated id=${diary.id} imageUrls=${diary.imageUrls.length}');

      log('saving diary to firestore...');
      await ref.read(diaryRepositoryProvider).saveDiary(userId!, diary);
      log('diary saved');

      ref.invalidate(latestDiaryProvider);

      if (!mounted) return;

      // ✅ 완료되면 Done으로 교체 이동
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CallDoneScreen(diary: diary,)),
      );
    } catch (e, st) {
      debugPrint('[CALL_LOADING][ERROR] $e\n$st');

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainScreen(
            snackMessage: '일기 생성에 실패했어요. 잠시 후 다시 시도해 주세요.',
          ),
        ),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 200),
              Image.asset(
                'asset/image/moon_images/grey_moon.png',
                width: 232,
                height: 232,
              ),
              const SizedBox(height: 40),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0x1affffff),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('일기 생성 중', style: TextStyle(color: Colors.white, fontSize: 16),),
                            const Text('잠시만 기다려주세요', style: TextStyle(color: Colors.white, fontSize: 16),),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
