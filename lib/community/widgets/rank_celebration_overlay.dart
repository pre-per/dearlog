import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/models/user_stats.dart';
import '../../user/providers/user_stats_providers.dart';

/// 새 랭크 진입 시 화면 중앙에 잠깐 떴다 사라지는 글래스 축하 오버레이.
///
/// 머티리얼 SnackBar/Dialog 를 쓰지 않고 직접 Stack + 파티클로 구현.
/// 흐름: 위에서 살짝 떨어지듯 등장 → 1.5s 머무름 → 페이드 아웃. 동시에 중심에서
/// 작은 파티클(별/꽃잎 형태) 이 사방으로 흩어진다.
class RankCelebrationOverlay extends StatefulWidget {
  final RankTier tier;
  final VoidCallback onDone;

  const RankCelebrationOverlay({
    super.key,
    required this.tier,
    required this.onDone,
  });

  @override
  State<RankCelebrationOverlay> createState() => _RankCelebrationOverlayState();
}

class _RankCelebrationOverlayState extends State<RankCelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _particleCtrl;
  late final List<_Particle> _particles;

  static const _enterDuration = Duration(milliseconds: 380);
  static const _holdDuration = Duration(milliseconds: 1500);
  static const _exitDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: _enterDuration,
    );
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    final rnd = math.Random();
    _particles = List.generate(24, (_) {
      final angle = rnd.nextDouble() * math.pi * 2;
      final speed = 60 + rnd.nextDouble() * 120;
      return _Particle(
        angle: angle,
        speed: speed,
        size: 4 + rnd.nextDouble() * 5,
        color: widget.tier.gradient[rnd.nextInt(widget.tier.gradient.length)],
        rotationSpeed: (rnd.nextDouble() - 0.5) * 8,
      );
    });

    _run();
  }

  Future<void> _run() async {
    await _enterCtrl.forward();
    _particleCtrl.forward();
    await Future.delayed(_holdDuration);
    if (!mounted) return;
    await _enterCtrl.reverse(from: 1.0).timeout(_exitDuration,
        onTimeout: () {});
    if (!mounted) return;
    widget.onDone();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([_enterCtrl, _particleCtrl]),
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_enterCtrl.value);
            return Stack(
              alignment: Alignment.center,
              children: [
                // 백그라운드 살짝 어두워지기 (시선 집중) — 매우 미세하게.
                Container(
                  color: Colors.black.withOpacity(0.18 * t),
                ),
                // 중앙 카드.
                Transform.translate(
                  offset: Offset(0, (1 - t) * -24),
                  child: Opacity(
                    opacity: t,
                    child: _CelebrationCard(tier: widget.tier),
                  ),
                ),
                // 파티클.
                CustomPaint(
                  size: Size.infinite,
                  painter: _ParticlePainter(
                    progress: _particleCtrl.value,
                    particles: _particles,
                    fadeIn: t,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  final RankTier tier;
  const _CelebrationCard({required this.tier});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.22),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: tier.gradient.first.withOpacity(0.6),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tier.gradient.last.withOpacity(0.65),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(tier.imagePath, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${tier.name} 등급 달성!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${tier.threshold}일의 기록을 이어왔어요',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double rotationSpeed;

  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotationSpeed,
  });
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  final double fadeIn;

  _ParticlePainter({
    required this.progress,
    required this.particles,
    required this.fadeIn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || fadeIn <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final easedT = Curves.easeOutQuad.transform(progress);

    for (final p in particles) {
      // 시간이 지날수록 멀리, 동시에 점점 투명해진다.
      final dist = p.speed * easedT;
      final dx = math.cos(p.angle) * dist;
      // 약간의 중력감 (y 가 시간에 따라 추가로 떨어짐)
      final dy = math.sin(p.angle) * dist + (40 * easedT * easedT);
      final pos = center + Offset(dx, dy);

      final alpha = (1.0 - progress).clamp(0.0, 1.0) * fadeIn;
      final paint = Paint()
        ..color = p.color.withOpacity(alpha * 0.85)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rotationSpeed * progress);
      // 작은 다이아몬드 모양 — 별처럼 보이게.
      final path = Path()
        ..moveTo(0, -p.size)
        ..lineTo(p.size * 0.55, 0)
        ..lineTo(0, p.size)
        ..lineTo(-p.size * 0.55, 0)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.progress != progress || old.fadeIn != fadeIn;
}

/// 앱 트리 어디든 한 번 감싸두면, 사용자의 user_stats 가 갱신돼서 새 티어에
/// 진입할 때마다 자동으로 [RankCelebrationOverlay] 를 띄운다.
///
/// 첫 emission(앱 시작 시 현재 티어 로드)은 baseline 으로 무시하고, 그 후로
/// 티어 index 가 증가하는 시점만 축하 대상이 된다. 따라서 새 일기로 인해
/// 티어가 올라간 직후 (Cloud Function 이 user_stats 를 갱신하고 stream 으로
/// emit 됨) 자연스럽게 한 번만 트리거된다.
class RankCelebrationHost extends ConsumerStatefulWidget {
  final Widget child;
  const RankCelebrationHost({super.key, required this.child});

  @override
  ConsumerState<RankCelebrationHost> createState() =>
      _RankCelebrationHostState();
}

class _RankCelebrationHostState extends ConsumerState<RankCelebrationHost> {
  bool _baselineSet = false;
  int _previousTierIndex = -1;
  RankTier? _celebrateTier;
  Key _celebrateKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserStats?>>(myUserStatsProvider, (prev, next) {
      final stats = next.valueOrNull;
      if (stats == null) return;
      final curTier = stats.tier;
      final curIdx =
          curTier == null ? -1 : RankTier.all.indexOf(curTier);

      if (!_baselineSet) {
        _baselineSet = true;
        _previousTierIndex = curIdx;
        return;
      }

      if (curIdx > _previousTierIndex && curTier != null) {
        setState(() {
          _celebrateTier = curTier;
          _celebrateKey = UniqueKey();
        });
      }
      _previousTierIndex = curIdx;
    });

    return Stack(
      children: [
        widget.child,
        if (_celebrateTier != null)
          RankCelebrationOverlay(
            key: _celebrateKey,
            tier: _celebrateTier!,
            onDone: () {
              if (!mounted) return;
              setState(() => _celebrateTier = null);
            },
          ),
      ],
    );
  }
}
