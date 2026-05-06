import 'package:dearlog/app.dart';
import 'package:flutter/material.dart';

/// 요일별 평균 기분 점수 막대 차트.
class WeekdayMoodCard extends ConsumerWidget {
  const WeekdayMoodCard({super.key});

  static const _gold = Color(0xFFFFD700);

  static const _labels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(monthlyStatsProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_view_week_rounded,
                  color: _gold, size: 18),
              const SizedBox(width: 6),
              Text(
                '요일별 기분',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '이 달의 요일별 평균 점수 — 막대가 길수록 기분이 좋았어요',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          asyncStats.when(
            loading: () => const SizedBox(height: 100),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) {
              final hasAny =
                  stats.weekday.counts.values.any((c) => c > 0);
              if (!hasAny) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '아직 기록이 부족해요',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return _Bars(weekday: stats.weekday);
            },
          ),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  final WeekdayMood weekday;
  const _Bars({required this.weekday});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final wd = i + 1; // 1..7
          final avg = weekday.averages[wd] ?? 0;
          final count = weekday.counts[wd] ?? 0;
          return Expanded(
            child: _Bar(
              label: WeekdayMoodCard._labels[i],
              avg: avg,
              count: count,
            ),
          );
        }),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double avg;
  final int count;
  const _Bar({
    required this.label,
    required this.avg,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    // 막대 길이: 0~100 절대값을 78px(=차트 높이 88 - label 영역) 안에 매핑.
    // 0선 위/아래로 그려서 음수는 0선 아래로 내려감.
    const maxBarH = 36.0;
    final magnitude = (avg.abs() / 100).clamp(0.0, 1.0);
    final barH = magnitude * maxBarH;
    final isPositive = avg >= 0;
    final hasData = count > 0;

    final barColor = !hasData
        ? Colors.white.withOpacity(0.08)
        : (isPositive
            ? const Color(0xFFD4A24C)
            : const Color(0xFFB58A6B));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 위쪽 영역: 양수 막대
          SizedBox(
            height: maxBarH,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: hasData && isPositive
                  ? _bar(barH, barColor, top: true)
                  : const SizedBox.shrink(),
            ),
          ),
          // 0선
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.18),
          ),
          // 아래쪽 영역: 음수 막대
          SizedBox(
            height: maxBarH,
            child: Align(
              alignment: Alignment.topCenter,
              child: hasData && !isPositive
                  ? _bar(barH, barColor, top: false)
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: hasData
                  ? Colors.white.withOpacity(0.9)
                  : Colors.white.withOpacity(0.55),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            hasData ? '${avg >= 0 ? '+' : ''}${avg.round()}' : '—',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double height, Color color, {required bool top}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.bottomCenter : Alignment.topCenter,
          end: top ? Alignment.topCenter : Alignment.bottomCenter,
          colors: [
            color,
            color.withOpacity(0.55),
          ],
        ),
        borderRadius: top
            ? const BorderRadius.vertical(top: Radius.circular(4))
            : const BorderRadius.vertical(bottom: Radius.circular(4)),
      ),
    );
  }
}
