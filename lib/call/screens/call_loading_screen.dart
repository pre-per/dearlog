import 'dart:async';
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
  static const _lines = <String>[
    '주요 감정 파악 중',
    '중요한 순간 추리는 중',
    '한 문장으로 요약 중',
    '의미 있는 장면 정리 중',
    '그림 일기 생성 중',
    '잠시만 기다려주세요',
  ];

  int _lineIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // ✅ 문구 순환 시작
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _lineIndex = (_lineIndex + 1) % _lines.length;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
      final diaryBase =
      await openaiService.generateDiaryFromMessages(messages, callId: callId);
      log('diary generated id=${diaryBase.id} imageUrls=${diaryBase.imageUrls.length}');

      log('generating analysis...');
      final analysis = await openaiService.generateAnalysisFromDiary(diaryBase);
      final diary = diaryBase.copyWith(analysis: analysis);
      log('analysis generated moodScore=${analysis.moodScore} valence=${analysis.valence}');

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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 1000),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final inAnim = Tween<Offset>(
                              begin: const Offset(0, 0.35),
                              end: Offset.zero,
                            ).animate(animation);

                            final outAnim = Tween<Offset>(
                              begin: Offset.zero,
                              end: const Offset(0, -0.35),
                            ).animate(animation);

                            final isIncoming = (child.key as ValueKey).value == _lineIndex;

                            return ClipRect(
                              child: SlideTransition(
                                position: isIncoming ? inAnim : outAnim,
                                child: FadeTransition(opacity: animation, child: child),
                              ),
                            );
                          },
                          child: Row(
                            key: ValueKey(_lineIndex),
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _lines[_lineIndex],
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(width: 2),
                              const AnimatedEllipsis(
                                // step 300ms면: . .. ... (0 포함) 이 약 1.2초 주기로 반복
                                step: Duration(milliseconds: 300),
                              ),
                            ],
                          ),
                        ),

                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(child: const Text('네트워크가 불안정하거나 앱을 종료하면 일기가 생성되지 않아요', style: TextStyle(color: Colors.red, fontSize: 12),)),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedEllipsis extends StatefulWidget {
  final TextStyle? style;
  final int maxDots; // 보통 3
  final Duration step; // 점 하나 늘어나는 간격

  const AnimatedEllipsis({
    super.key,
    this.style,
    this.maxDots = 3,
    this.step = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedEllipsis> createState() => _AnimatedEllipsisState();
}

class _AnimatedEllipsisState extends State<AnimatedEllipsis>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    // 0..maxDots 까지 갔다가 다시 0으로 반복
    final totalSteps = widget.maxDots + 1; // 0 포함
    final totalDuration = widget.step * totalSteps;

    _controller = AnimationController(vsync: this, duration: totalDuration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final totalSteps = widget.maxDots + 1;
        final idx = (_controller.value * totalSteps).floor().clamp(0, widget.maxDots);
        final dots = '.' * idx;

        return Text(
          dots,
          style: widget.style,
        );
      },
    );
  }
}
