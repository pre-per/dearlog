import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/models/user_stats.dart';
import '../../user/providers/user_stats_providers.dart';
import 'streak_avatar_glow.dart';

/// 내 일기 기록 통계를 한눈에 보여주는 글래스 카드.
///
/// 표시 정보:
///   - 현재 티어 (이모지 + 이름) + 다음 티어까지 며칠 + progress bar
///   - 현재 연속 일수 (스트릭) 글로우 미리보기
///   - 최장 연속 일수, 총 기록 일수
///
/// 설정 화면, 프로필 화면 등 어디서나 1줄로 삽입 가능.
class MyRankCard extends ConsumerWidget {
  const MyRankCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(myUserStatsProvider);
    final stats =
        statsAsync.maybeWhen(data: (s) => s, orElse: () => null) ??
            UserStats.empty();
    final liveStreak = liveCurrentStreak(stats);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '내 기록',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 14),
              _TierRow(stats: stats, liveStreak: liveStreak),
              const SizedBox(height: 16),
              _NextTierProgress(stats: stats),
              const SizedBox(height: 16),
              _StreakAndTotalsRow(stats: stats, liveStreak: liveStreak),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final UserStats stats;
  final int liveStreak;
  const _TierRow({required this.stats, required this.liveStreak});

  @override
  Widget build(BuildContext context) {
    final tier = stats.tier;
    return Row(
      children: [
        StreakAvatarGlow(
          streak: liveStreak,
          avatarSize: 56,
          child: SizedBox(
            width: 56,
            height: 56,
            child: tier == null
                ? Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3A3A4A), Color(0xFF222231)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '?',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ClipOval(
                    child: Image.asset(tier.imagePath, fit: BoxFit.cover),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tier?.name ?? '미진입',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tier == null
                    ? '아직 등급에 진입하지 못했어요'
                    : '${tier.threshold}일 이상 기록 달성',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextTierProgress extends StatelessWidget {
  final UserStats stats;
  const _NextTierProgress({required this.stats});

  @override
  Widget build(BuildContext context) {
    final next = stats.nextTier;
    if (next == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: Text(
          '✨ 최고 등급에 도달했어요! 기록을 계속 이어가요.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final current = stats.tier;
    final fromThreshold = current?.threshold ?? 0;
    final span = next.threshold - fromThreshold;
    final progressDays = stats.diaryCount - fromThreshold;
    final progress = span <= 0
        ? 0.0
        : (progressDays / span).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '다음 등급',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 14,
              height: 14,
              child: ClipOval(
                child: Image.asset(next.imagePath, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              next.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '· ${stats.daysToNextTier ?? 0}일 남음',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                height: 6,
                color: Colors.white.withOpacity(0.08),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: next.gradient,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreakAndTotalsRow extends StatelessWidget {
  final UserStats stats;
  final int liveStreak;
  const _StreakAndTotalsRow({required this.stats, required this.liveStreak});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: '현재 연속',
            value: '$liveStreak일',
            accent: liveStreak >= 5
                ? const Color(0xFFFFB347)
                : Colors.white,
          ),
        ),
        _divider(),
        Expanded(
          child: _Stat(
            label: '최장 연속',
            value: '${stats.longestStreak}일',
            accent: Colors.white,
          ),
        ),
        _divider(),
        Expanded(
          child: _Stat(
            label: '총 기록',
            value: '${stats.diaryCount}일',
            accent: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 28,
        color: Colors.white.withOpacity(0.08),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _Stat({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: accent,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
