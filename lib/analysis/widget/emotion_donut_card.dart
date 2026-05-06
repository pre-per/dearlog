import 'dart:math' as math;

import 'package:dearlog/app.dart';
import 'package:dearlog/analysis/widget/keyword_color_palette.dart';
import 'package:flutter/material.dart';

/// 이번 달 일별 top 감정 분포 도넛 차트.
class EmotionDonutCard extends ConsumerWidget {
  const EmotionDonutCard({super.key});

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(monthlyStatsProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.donut_small_rounded, color: _gold, size: 18),
              const SizedBox(width: 6),
              Text(
                '감정 분포',
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
            '하루의 가장 두드러진 감정 비율',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          asyncStats.when(
            loading: () => const SizedBox(height: 100),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) {
              if (stats.emotionDistribution.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '아직 분포가 없어요',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return _DonutWithLegend(
                  distribution: stats.emotionDistribution);
            },
          ),
        ],
      ),
    );
  }
}

class _DonutWithLegend extends StatelessWidget {
  final Map<String, int> distribution;
  const _DonutWithLegend({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final entries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (a, b) => a + b.value);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(
            painter: _DonutPainter(entries: entries, total: total),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '일',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: entries.take(5).map((e) {
              final pct = (e.value / total * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: keywordGlowColor(e.key),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final int total;
  _DonutPainter({required this.entries, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;
    for (final e in entries) {
      final sweep = (e.value / total) * 2 * math.pi;
      final color = keywordGlowColor(e.key);
      canvas.drawArc(
        rect,
        startAngle,
        sweep - 0.02, // 작은 갭
        false,
        Paint()
          ..color = color
          ..strokeWidth = 14
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.entries != entries || old.total != total;
}
