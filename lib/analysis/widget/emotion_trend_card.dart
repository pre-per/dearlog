import 'dart:math' as math;
import 'package:dearlog/app.dart';

class EmotionTrendCard extends ConsumerWidget {
  const EmotionTrendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(analysisRangeProvider);
    final pointsAsync = ref.watch(trendPointsProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '감정 추세',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          pointsAsync.when(
            data:
                (points) => SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: _TrendChart(points: points, range: range),
                ),
            loading:
                () => const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
            error:
                (e, _) => SizedBox(
                  height: 180,
                  child: Center(
                    child: Text(
                      '오류: $e',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<TrendPoint> points;
  final AnalysisRange range; // ✅ 추가
  const _TrendChart({required this.points, required this.range});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text('표시할 데이터가 없어요.', style: TextStyle(color: Colors.white70)),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;

        final n = points.length;
        final leftPad = 18.0;
        final rightPad = 18.0;
        final topPad = 18.0;
        final bottomPad = 26.0;

        double xAt(int i) {
          if (n == 1) return w / 2;
          final usable = w - leftPad - rightPad;
          return leftPad + (usable * (i / (n - 1)));
        }

        double yFromScore(int score) {
          final clamped = score.clamp(0, 100);
          final usable = h - topPad - bottomPad;
          return topPad + (usable * (1 - clamped / 100.0));
        }

        final positions = List.generate(n, (i) {
          return Offset(xAt(i), yFromScore(points[i].moodScore));
        });

        return Stack(
          children: [
            CustomPaint(
              size: Size(w, h),
              painter: _TrendLinePainter(positions: positions),
            ),

            for (int i = 0; i < n; i++)
              Positioned(
                left: positions[i].dx - 16,
                top: positions[i].dy - 16,
                child: _PlanetDot(
                  asset: planetAssetForEmotion(
                    points[i].emotionLabel,
                    rounded: false,
                  ),
                ),
              ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(n, (i) {
                  final d = points[i].date;
                  final label = _formatTrendLabel(d, range); // ✅ 여기
                  return SizedBox(
                    width: 60,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlanetDot extends StatelessWidget {
  final String asset;

  const _PlanetDot({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<Offset> positions;

  _TrendLinePainter({required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    // 점선 라인
    final line =
        Paint()
          ..color = Colors.white.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;

    for (int i = 0; i < positions.length - 1; i++) {
      _drawDashedLine(
        canvas,
        positions[i],
        positions[i + 1],
        line,
        dash: 6,
        gap: 6,
      );
    }

    // 하단 기준선
    final baseY = size.height - 22;
    canvas.drawLine(
      Offset(10, baseY),
      Offset(size.width - 10, baseY),
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..strokeWidth = 1,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    double dash = 6,
    double gap = 6,
  }) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;

    final vx = dx / dist;
    final vy = dy / dist;

    double t = 0;
    while (t < dist) {
      final start = Offset(a.dx + vx * t, a.dy + vy * t);
      final endT = math.min(t + dash, dist);
      final end = Offset(a.dx + vx * endT, a.dy + vy * endT);
      canvas.drawLine(start, end, paint);
      t += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.positions != positions;
  }
}

String _formatTrendLabel(DateTime d, AnalysisRange range) {
  switch (range) {
    case AnalysisRange.daily:
      return '${d.month}/${d.day}';

    case AnalysisRange.weekly:
      // ✅ "00월 0주" = 해당 날짜가 그 달의 몇 번째 주인지
      final week = _weekOfMonth(d);
      return '${d.month}월 ${week}주';

    case AnalysisRange.monthly:
      return '${d.month}월';
  }
}

/// 해당 날짜가 그 달의 몇 번째 주인지 (1주~5주)
/// 규칙: "그 달 1일이 속한 주"를 1주로 계산 (일요일 시작 기준)
int _weekOfMonth(DateTime d) {
  final first = DateTime(d.year, d.month, 1);

  // Dart weekday: Mon=1 ... Sun=7
  // 일요일 시작(0)으로 바꾸기: Sun=0, Mon=1, ... Sat=6
  int toSundayStart(int weekday) => weekday % 7;

  final firstOffset = toSundayStart(first.weekday);
  final dayIndex = d.day - 1;

  return ((firstOffset + dayIndex) ~/ 7) + 1;
}
