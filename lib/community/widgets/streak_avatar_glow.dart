import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../user/models/user_stats.dart';

/// 사용자의 연속 기록(스트릭) 일수에 따라 아바타 주위에 글로우를 입힌다.
///
/// 동기 부여 곡선:
///   - 1일: 효과 없음 (clean).
///   - 2~4일: 화이트→웜 톤이 점진적으로 강해지는 부드러운 글로우 + 미세 펄스.
///   - 5~6일: 골든 글로우 + 우측 상단 🔥 작은 아이콘.
///   - 7일+: 광선 추가 (8방향 짧은 streak).
///   - 14일+: 블루-골드 혼합.
///   - 30일+: 무지개 스윕 그라데이션 후광.
///
/// 글래스 톤 디자인 원칙에 따라 머티리얼 위젯은 사용하지 않고 Container/Stack/
/// CustomPaint 로 직접 그린다.
class StreakAvatarGlow extends StatefulWidget {
  /// 현재 연속 일수. 0 또는 1 이면 글로우 없이 [child] 만 표시.
  final int streak;

  /// 글로우가 감쌀 자식 위젯 (보통 CommunityAvatar).
  final Widget child;

  /// 아바타의 시각적 사이즈. 글로우 padding/rays 계산 기준.
  final double avatarSize;

  const StreakAvatarGlow({
    super.key,
    required this.streak,
    required this.child,
    this.avatarSize = 36,
  });

  @override
  State<StreakAvatarGlow> createState() => _StreakAvatarGlowState();
}

class _StreakAvatarGlowState extends State<StreakAvatarGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = StreakGlowLevel.forStreak(widget.streak);
    if (level == null) {
      // 1일 이하 — 그냥 자식만 노출.
      return widget.child;
    }

    // 레이아웃 footprint 는 아바타 사이즈와 동일하게 고정한다 — 글로우/광선/🔥 는
    // Stack 의 clipBehavior: Clip.none 덕분에 시각적으로만 넘쳐서 주변 텍스트나
    // 카드 폭에 영향을 주지 않는다.
    final size = widget.avatarSize;
    final showFlame = level.showFlame;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = (math.sin(_ctrl.value * math.pi * 2) + 1) / 2;
        final pulse = level.pulse ? t : 1.0;
        final glowOpacity = level.pulse
            ? (1.0 - level.pulseIntensity) + level.pulseIntensity * pulse
            : 1.0;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // ── 글로우 본체 (BoxShadow 는 SizedBox 를 시각적으로 넘침) ──
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: level.color.withOpacity(0.7 * glowOpacity),
                      blurRadius: level.blurRadius * 0.7,
                      spreadRadius: 0.5,
                    ),
                    if (level.minStreak >= 14)
                      BoxShadow(
                        color: const Color(0xFF6BCBFF)
                            .withOpacity(0.4 * glowOpacity),
                        blurRadius: level.blurRadius * 0.5,
                        spreadRadius: 0.5,
                      ),
                  ],
                ),
              ),

              // ── 무지개 띠 (30일+) — 아바타 둘레 얇은 링으로 톤다운 ──
              if (level.rainbow)
                Container(
                  width: size + 4,
                  height: size + 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [
                        Color(0xFFFF6B6B),
                        Color(0xFFFFD93D),
                        Color(0xFF6BCB77),
                        Color(0xFF4D96FF),
                        Color(0xFFB983FF),
                        Color(0xFFFF6B6B),
                      ],
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                    ),
                  ),
                ),

              // ── 아바타 본체 ──
              widget.child,

              // ── 🔥 (5일+) — 아바타 우측 상단 모서리에 작게 배치 ──
              if (showFlame)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: size * 0.36,
                    height: size * 0.36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFB347).withOpacity(0.8),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '🔥',
                      style: TextStyle(
                        fontSize: size * 0.24,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

