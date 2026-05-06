import 'package:dearlog/app.dart';
import 'package:flutter/material.dart';

/// 이번 달 vs 직전 달 — 평균 기분 변화 + 새로 들어온/사라진 키워드.
class MonthComparisonCard extends ConsumerWidget {
  const MonthComparisonCard({super.key});

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(monthlyStatsProvider);
    final month = ref.watch(selectedMonthProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded,
                  color: _gold, size: 18),
              const SizedBox(width: 6),
              Text(
                '지난 달 대비',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${month.previous.label} → ${month.label}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          asyncStats.when(
            loading: () => const SizedBox(height: 60),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) {
              final c = stats.comparison;
              if (c == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '비교할 이전 기록이 없어요',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                );
              }
              return _Body(comparison: c);
            },
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final MonthComparison comparison;
  const _Body({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final delta = comparison.delta;
    final isUp = delta > 0;
    final isFlat = delta.abs() < 1;
    final accent = isFlat
        ? Colors.white.withOpacity(0.6)
        : (isUp
            ? const Color(0xFF4ADE80)
            : const Color(0xFFFF7B7B));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─ 평균 기분 변화 ─
        Row(
          children: [
            Text(
              '평균 기분',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${comparison.prevAvg >= 0 ? '+' : ''}${comparison.prevAvg.round()}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded,
                color: Colors.white.withOpacity(0.62), size: 14),
            const SizedBox(width: 6),
            Text(
              '${comparison.currentAvg >= 0 ? '+' : ''}${comparison.currentAvg.round()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isFlat)
                    Icon(
                      isUp
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: accent,
                      size: 11,
                    ),
                  if (!isFlat) const SizedBox(width: 2),
                  Text(
                    isFlat
                        ? '거의 같음'
                        : '${isUp ? '+' : ''}${delta.round()}점',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ─ 새로 들어온 / 사라진 키워드 ─
        if (comparison.appeared.isNotEmpty)
          _DiffRow(
            icon: Icons.add_circle_outline_rounded,
            color: const Color(0xFF4ADE80),
            label: '새로',
            keywords: comparison.appeared,
          ),
        if (comparison.appeared.isNotEmpty &&
            comparison.disappeared.isNotEmpty)
          const SizedBox(height: 8),
        if (comparison.disappeared.isNotEmpty)
          _DiffRow(
            icon: Icons.remove_circle_outline_rounded,
            color: const Color(0xFFFF7B7B),
            label: '사라진',
            keywords: comparison.disappeared,
          ),
      ],
    );
  }
}

class _DiffRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final List<String> keywords;

  const _DiffRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.keywords,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 5,
            runSpacing: 4,
            children: keywords
                .map((w) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Text(
                        w,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'GowunBatang',
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
