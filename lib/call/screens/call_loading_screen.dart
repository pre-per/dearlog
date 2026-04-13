import 'dart:async';
import 'dart:math';
import 'package:dearlog/app.dart';
import 'package:dearlog/call/services/conversation_backup_service.dart';
import 'package:uuid/uuid.dart';

enum _Phase { loading, done }

class CallLoadingScreen extends ConsumerStatefulWidget {
  final Duration elapsed;

  const CallLoadingScreen({super.key, required this.elapsed});

  @override
  ConsumerState<CallLoadingScreen> createState() => _CallLoadingScreenState();
}

class _CallLoadingScreenState extends ConsumerState<CallLoadingScreen>
    with TickerProviderStateMixin {

  // ─── State ────────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.loading;
  DiaryEntry? _diary;
  int _currentStep = 0;

  static const _totalSteps = 4;
  static const _stepLabels = [
    '대화를 저장하는 중',
    '일기를 작성하는 중',
    '감정을 분석하는 중',
    '그림일기를 그리는 중',
  ];

  // ─── Animation Controllers ────────────────────────────────────────────────
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  late final AnimationController _sparkleCtrl;

  late final AnimationController _arcCtrl;
  late Animation<double> _arcAnim;

  // Slow creep timer for image generation step
  Timer? _creepTimer;

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _arcCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _arcAnim = Tween<double>(begin: 0.0, end: 0.0).animate(_arcCtrl);

    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _creepTimer?.cancel();
    _glowCtrl.dispose();
    _sparkleCtrl.dispose();
    _arcCtrl.dispose();
    super.dispose();
  }

  // ─── Arc helpers ──────────────────────────────────────────────────────────
  double get _arcValue => _arcAnim.value;

  void _animateArcTo(double target, {Duration duration = const Duration(milliseconds: 900)}) {
    final from = _arcValue;
    _arcCtrl.stop();
    _arcCtrl.duration = duration;
    _arcAnim = Tween<double>(begin: from, end: target).animate(
      CurvedAnimation(parent: _arcCtrl, curve: Curves.easeOutCubic),
    );
    _arcCtrl.forward(from: 0);
  }

  void _startCreep() {
    // 0.75 → 0.92 over ~30s via small increments
    _creepTimer?.cancel();
    _creepTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_arcValue >= 0.99) { timer.cancel(); return; }
      _animateArcTo(
        (_arcValue + 0.002).clamp(0.0, 0.99),
        duration: const Duration(milliseconds: 400),
      );
    });
  }

  // ─── Step advancement ─────────────────────────────────────────────────────
  void _advanceStep(int step) {
    if (!mounted) return;
    final clamped = step.clamp(0, _totalSteps - 1);
    setState(() => _currentStep = clamped);

    _creepTimer?.cancel();
    _creepTimer = null;

    if (step == 3) {
      _animateArcTo(0.75);
      // After the quick snap to 0.75, start the slow creep
      Future.delayed(const Duration(milliseconds: 950), () {
        if (mounted && _currentStep == 3 && _phase == _Phase.loading) _startCreep();
      });
    } else {
      _animateArcTo(step / _totalSteps);
    }
  }

  // ─── Main logic ───────────────────────────────────────────────────────────
  Future<void> _run() async {
    void log(String msg) => debugPrint('[CALL_LOADING] $msg');

    try {
      final openaiService = OpenAIService();
      final userId = ref.read(userIdProvider);
      final callId = const Uuid().v4();
      final messages = ref.read(messageProvider);

      log('userId=$userId callId=$callId messages=${messages.length}');

      _advanceStep(0);

      if (userId != null) {
        log('saving call...');
        await ref.read(callRepositoryProvider).saveCall(
          userId,
          Call(
            callId: callId,
            timestamp: DateTime.now(),
            duration: widget.elapsed,
            messages: messages,
          ),
        );
        log('call saved');
      }

      await ConversationBackupService.save(messages);

      log('generating diary...');
      final diary = await openaiService.generateDiaryFromMessages(
        messages,
        callId: callId,
        onStep: _advanceStep,
      );
      log('diary generated id=${diary.id} moodScore=${diary.analysis?.moodScore}');

      log('saving diary...');
      await ref.read(diaryRepositoryProvider).saveDiary(userId!, diary);
      log('diary saved');

      ref.invalidate(latestDiaryProvider);
      await ConversationBackupService.clear();
      ref.read(messageProvider.notifier).clear();

      if (!mounted) return;

      // ── Complete arc → wait → reveal done content ──
      _creepTimer?.cancel();
      _animateArcTo(1.0, duration: const Duration(milliseconds: 700));
      await Future.delayed(const Duration(milliseconds: 900));

      if (!mounted) return;
      setState(() {
        _diary = diary;
        _phase = _Phase.done;
      });

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

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _Phase.done,
      child: BaseScaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // ── Moon + Arc ──────────────────────────────────────────────
                AnimatedBuilder(
                  animation: Listenable.merge([_glowCtrl, _sparkleCtrl, _arcCtrl]),
                  builder: (context, _) {
                    final moonAsset = _phase == _Phase.done && _diary != null
                        ? planetAssetForEmotion(_diary!.emotion)
                        : 'asset/image/moon_images/grey_moon.png';

                    return SizedBox(
                      width: 280,
                      height: 280,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _GlowRing(size: 260, opacity: 0.07 * _glowAnim.value),
                          _GlowRing(size: 245, opacity: 0.05 * _glowAnim.value),

                          CustomPaint(
                            size: const Size(258, 258),
                            painter: _ArcProgressPainter(
                              progress: _arcValue,
                              glowIntensity: _glowAnim.value,
                              isComplete: _phase == _Phase.done,
                            ),
                          ),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 900),
                            child: Image.asset(
                              moonAsset,
                              key: ValueKey(moonAsset),
                              width: 232,
                              height: 232,
                            ),
                          ),

                          CustomPaint(
                            size: const Size(280, 280),
                            painter: _SparklePainter(t: _sparkleCtrl.value),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 44),

                // ── Content area: loading ↔ done ────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _phase == _Phase.done
                      ? _DoneContent(diary: _diary!, key: const ValueKey('done'))
                      : _LoadingContent(
                          key: const ValueKey('loading'),
                          currentStep: _currentStep,
                          totalSteps: _totalSteps,
                          stepLabels: _stepLabels,
                        ),
                ),

                const Spacer(),

                if (_phase == _Phase.loading)
                  Text(
                    '네트워크가 불안정하거나 앱을 종료하면 일기가 생성되지 않아요',
                    style: TextStyle(color: Colors.red.withOpacity(0.65), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Loading content ─────────────────────────────────────────────────────────

class _LoadingContent extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;

  const _LoadingContent({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Step dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalSteps, (i) {
            final isDone = i < currentStep;
            final isActive = i == currentStep;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: (isActive || isDone)
                    ? const Color(0xFFFFD700)
                    : Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),

        const SizedBox(height: 20),

        // Step label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Row(
            key: ValueKey(currentStep),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stepLabels[currentStep],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              const AnimatedEllipsis(step: Duration(milliseconds: 350)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Done content ─────────────────────────────────────────────────────────────

class _DoneContent extends StatelessWidget {
  final DiaryEntry diary;

  const _DoneContent({super.key, required this.diary});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '오늘의 일기가 완성됐어요',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          diary.title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (diary.aiComment != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Text(
              diary.aiComment!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 20),

        // 일기 확인하기
        GestureDetector(
          onTap: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MainScreen()),
              (route) => false,
            );
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DiaryDetailScreen(diary: diary)),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
            ),
            child: const Center(
              child: Text(
                '오늘의 일기 확인하기',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 홈으로
        GestureDetector(
          onTap: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MainScreen()),
              (route) => false,
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Center(
              child: Text(
                '홈으로',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Glow Ring ───────────────────────────────────────────────────────────────

class _GlowRing extends StatelessWidget {
  final double size;
  final double opacity;

  const _GlowRing({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(opacity),
            blurRadius: 24,
            spreadRadius: 6,
          ),
        ],
      ),
    );
  }
}

// ─── Arc Progress Painter ─────────────────────────────────────────────────────

class _ArcProgressPainter extends CustomPainter {
  final double progress;
  final double glowIntensity;
  final bool isComplete;

  const _ArcProgressPainter({
    required this.progress,
    required this.glowIntensity,
    required this.isComplete,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Track ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    if (progress <= 0) return;

    final sweepAngle = progress * 2 * pi;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Glow layer
    canvas.drawArc(
      rect,
      -pi / 2,
      sweepAngle,
      false,
      Paint()
        ..color = const Color(0xFFFFD700).withOpacity(0.28 * glowIntensity)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Main arc
    canvas.drawArc(
      rect,
      -pi / 2,
      sweepAngle,
      false,
      Paint()
        ..color = const Color(0xFFFFD700).withOpacity(0.92)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Arc tip dot (hidden when complete — full circle looks cleaner)
    if (!isComplete) {
      final tipAngle = -pi / 2 + sweepAngle;
      final tip = Offset(
        center.dx + radius * cos(tipAngle),
        center.dy + radius * sin(tipAngle),
      );
      canvas.drawCircle(
        tip,
        8,
        Paint()
          ..color = const Color(0xFFFFD700).withOpacity(0.45 * glowIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(tip, 3.5, Paint()..color = const Color(0xFFFFD700));
    }
  }

  @override
  bool shouldRepaint(_ArcProgressPainter old) =>
      old.progress != progress ||
      old.glowIntensity != glowIntensity ||
      old.isComplete != isComplete;
}

// ─── Sparkle Painter ──────────────────────────────────────────────────────────

class _SparklePainter extends CustomPainter {
  final double t;

  static final _rng = Random(77);
  static final _particles = List.generate(14, (i) {
    final angle = (i / 14) * 2 * pi + _rng.nextDouble() * 0.4;
    final speed = 0.25 + _rng.nextDouble() * 0.45;
    final phase = _rng.nextDouble();
    return (angle: angle, speed: speed, phase: phase);
  });

  const _SparklePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const moonRadius = 116.0;
    final paint = Paint();

    for (final p in _particles) {
      final raw = (t * p.speed + p.phase) % 1.0;
      if (raw > 0.55) continue;

      final eased = Curves.easeOut.transform(raw / 0.55);
      final r = moonRadius + 6 + eased * 32;
      final opacity = (1.0 - eased) * 0.65;
      final dotSize = (1.0 - eased) * 2.2;
      final drift = t * 0.15;

      final pos = Offset(
        center.dx + r * cos(p.angle + drift),
        center.dy + r * sin(p.angle + drift),
      );

      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(pos, dotSize, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}

// ─── Animated Ellipsis ───────────────────────────────────────────────────────

class AnimatedEllipsis extends StatefulWidget {
  final TextStyle? style;
  final int maxDots;
  final Duration step;

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
    final totalSteps = widget.maxDots + 1;
    _controller = AnimationController(
      vsync: this,
      duration: widget.step * totalSteps,
    )..repeat();
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
        return Text('.' * idx, style: widget.style);
      },
    );
  }
}
