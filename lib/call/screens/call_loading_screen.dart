import 'dart:async';
import 'dart:math';
import 'package:dearlog/app.dart';
import 'package:dearlog/call/services/conversation_backup_service.dart';
import 'package:uuid/uuid.dart';

enum _Phase { loading, done }

class CallLoadingScreen extends ConsumerStatefulWidget {
  final Duration elapsed;

  const CallLoadingScreen({
    super.key,
    required this.elapsed,
  });

  @override
  ConsumerState<CallLoadingScreen> createState() => _CallLoadingScreenState();
}

class _CallLoadingScreenState extends ConsumerState<CallLoadingScreen>
    with TickerProviderStateMixin {

  // ─── State ────────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.loading;
  DiaryEntry? _diary;
  int _currentStep = 0;

  // 일기 생성이 비정상적으로 오래 걸릴 때 사용자에게 빠져나갈 길을 열어준다.
  // - 90초가 지나면 "그만두기" 버튼 노출.
  // - 글로벌 4분 타임아웃 — 그 이상은 강제로 메인 복귀.
  bool _showAbortHint = false;
  bool _aborted = false;
  Timer? _abortHintTimer;
  static const Duration _kAbortHintAfter = Duration(seconds: 90);
  static const Duration _kGlobalTimeout = Duration(minutes: 4);

  static const List<String> _stepLabels = [
    '대화를 저장하는 중',
    '일기를 작성하는 중',
    '감정을 분석하는 중',
  ];

  static const int _totalSteps = 3;

  // ─── Animation Controllers ────────────────────────────────────────────────
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  late final AnimationController _sparkleCtrl;

  late final AnimationController _arcCtrl;
  late Animation<double> _arcAnim;

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

    _abortHintTimer = Timer(_kAbortHintAfter, () {
      if (!mounted) return;
      if (_phase != _Phase.loading) return;
      setState(() => _showAbortHint = true);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _abortHintTimer?.cancel();
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

  // ─── Step advancement ─────────────────────────────────────────────────────
  void _advanceStep(int step) {
    if (!mounted) return;
    final clamped = step.clamp(0, _totalSteps - 1);
    setState(() => _currentStep = clamped);
    _animateArcTo(step / _totalSteps);
  }

  // ─── Main logic ───────────────────────────────────────────────────────────
  Future<void> _run() async {
    void log(String msg) => debugPrint('[CALL_LOADING] $msg');

    try {
      // 글로벌 타임아웃: 내부 호출들에 각자 타임아웃이 있어도, 합산이
      // 비정상적으로 길어질 때를 대비해 외곽에서 한 번 더 막는다.
      // 백업은 이미 _runFlow 초입에서 저장되므로 사용자가 다시 들어와도
      // ConversationBackupService 로 복구 가능.
      await _runFlow(log).timeout(_kGlobalTimeout);
    } on TimeoutException {
      debugPrint('[CALL_LOADING][ERROR] global timeout');
      if (!mounted) return;
      _exitToMainWithMessage(
        '일기 생성이 너무 오래 걸려서 잠시 멈췄어요. 대화는 안전하게 보관됐으니 잠시 후 다시 시도해 주세요.',
      );
    } catch (e, st) {
      // 사용자가 직접 그만두기 누른 경우는 별도 처리 후 재throw.
      if (_aborted) return;
      debugPrint('[CALL_LOADING][ERROR] $e\n$st');
      if (!mounted) return;
      final msg = e is OpenAIServiceException
          ? e.userMessage
          : '일기 생성에 실패했어요. 잠시 후 다시 시도해 주세요.';
      _exitToMainWithMessage(msg);
    }
  }

  Future<void> _runFlow(void Function(String) log) async {
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
    final existingKeywords = ref.read(currentMonthExistingKeywordsProvider);
    log('existing keywords (${existingKeywords.length}): ${existingKeywords.join(", ")}');
    final diary = await openaiService.generateDiaryFromMessages(
      messages,
      userId: userId!,
      callId: callId,
      onStep: _advanceStep,
      existingKeywords: existingKeywords,
    );
    log('diary generated id=${diary.id} emotions=${diary.analysis?.emotions.map((e) => e.name).join(",")}');

    if (_aborted || !mounted) return;

    log('saving diary...');
    await ref.read(diaryRepositoryProvider).saveDiary(userId, diary);
    log('diary saved');

    ref.invalidate(latestDiaryProvider);
    await ConversationBackupService.clear();
    ref.read(messageProvider.notifier).clear();

    if (!mounted) return;

    // ── Complete arc → wait → reveal done content ──
    _animateArcTo(1.0, duration: const Duration(milliseconds: 700));
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() {
      _diary = diary;
      _phase = _Phase.done;
    });
  }

  /// 사용자가 "그만두기" 누름 — 백업은 그대로 두고 메인으로 빠짐.
  /// (다음 통화 진입 시 ConversationBackupService 가 복구를 제안)
  Future<void> _onAbortPressed() async {
    final ok = await showGlassDialog<bool>(
      context: context,
      title: '일기 생성을 그만둘까요?',
      message: '대화 내용은 안전하게 보관돼요.\n잠시 후 다시 시도하면 이어서 일기를 만들 수 있어요.',
      actions: const [
        GlassDialogAction(label: '계속 기다리기', value: false),
        GlassDialogAction(label: '그만두기', value: true, isDestructive: true),
      ],
    );
    if (ok != true) return;
    if (!mounted) return;
    _aborted = true;
    _exitToMainWithMessage('일기 생성을 멈췄어요. 대화는 안전하게 보관됐으니 잠시 후 다시 시도해 주세요.');
  }

  void _exitToMainWithMessage(String msg) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainScreen(snackMessage: msg),
      ),
      (route) => false,
    );
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
                              totalSteps: _totalSteps,
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

                // 90초 이상 경과 시 노출되는 "그만두기" 버튼.
                // 너무 일찍 보여주면 사용자가 정상 흐름에서도 불안하게 누를 수 있어 늦게 띄움.
                if (_phase == _Phase.loading && _showAbortHint) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _onAbortPressed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: Text(
                        '그만두고 메인으로 돌아가기',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
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
  /// 단계 boundary 틱 표시용. 그림일기 ON이면 4, OFF면 3.
  final int totalSteps;

  const _ArcProgressPainter({
    required this.progress,
    required this.glowIntensity,
    required this.isComplete,
    this.totalSteps = 4,
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

    // Step boundary ticks — totalSteps에 따라 갯수 다름.
    // 단계 사이 경계에만 표시 (시작/끝 제외).
    for (int i = 1; i < totalSteps; i++) {
      final tickAngle = -pi / 2 + (i / totalSteps) * 2 * pi;
      final tickPos = Offset(
        center.dx + radius * cos(tickAngle),
        center.dy + radius * sin(tickAngle),
      );
      final passed = (i / totalSteps) <= progress;
      // 지나간 틱은 금색 글로우, 미진행은 무채색.
      canvas.drawCircle(
        tickPos,
        passed ? 3.2 : 2.4,
        Paint()
          ..color = passed
              ? const Color(0xFFFFD700).withOpacity(0.85)
              : Colors.white.withOpacity(0.32),
      );
      if (passed) {
        canvas.drawCircle(
          tickPos,
          5.5,
          Paint()
            ..color = const Color(0xFFFFD700).withOpacity(0.35 * glowIntensity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }

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
      old.isComplete != isComplete ||
      old.totalSteps != totalSteps;
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
