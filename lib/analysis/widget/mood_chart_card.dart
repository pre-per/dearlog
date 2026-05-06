import 'dart:math' as math;

import 'package:dearlog/app.dart';
import 'package:flutter/material.dart';

/// 한 달 기분 흐름 라인 차트.
///
/// - 가로축: 1일 ~ 마지막 날
/// - 세로축: -100 ~ +100 (0 = 평소)
/// - 금색 그라데이션 라인 + 글로우 + 데이터 포인트
/// - 극점에는 명사 말풍선 (탭하면 해당 일기 detail로 이동)
class MoodChartCard extends ConsumerWidget {
  const MoodChartCard({super.key});

  static const _gold = Color(0xFFD4A24C);
  static const _goldBright = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSeries = ref.watch(monthlyMoodSeriesProvider);
    final month = ref.watch(selectedMonthProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  color: _goldBright, size: 18),
              const SizedBox(width: 6),
              Text(
                '한 달의 기분 흐름',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              asyncSeries.maybeWhen(
                data: (data) => Text(
                  '${data.points.length}일 기록',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          asyncSeries.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _gold),
                ),
              ),
            ),
            error: (_, __) => SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  '기분 데이터를 불러오지 못했어요',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.78), fontSize: 13),
                ),
              ),
            ),
            data: (data) {
              if (data.isEmpty) {
                return const _EmptyState();
              }
              return _MoodChart(
                data: data,
                year: month.year,
                month: month.month,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline_rounded,
                color: Colors.white.withOpacity(0.45), size: 36),
            const SizedBox(height: 10),
            Text(
              '이번 달 기록이 아직 없어요',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.78), fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '하루를 기록하면 기분 흐름이 그려져요',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.58), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChart extends ConsumerWidget {
  final MoodSeriesData data;
  final int year;
  final int month;

  const _MoodChart({
    required this.data,
    required this.year,
    required this.month,
  });

  // 차트 영역 패딩: 위/아래는 말풍선 공간 확보용.
  // 좌우는 GlassCard 외부 패딩이 16px 있으므로 작게.
  static const _padTop = 30.0;
  static const _padBottom = 26.0;
  static const _padLeft = 8.0;
  static const _padRight = 8.0;
  static const _chartHeight = 210.0;

  // 봉우리/골짜기 말풍선 분기 임계 — 실제 점수 0 기준.
  bool _isPositive(MoodPoint p) => p.score >= 0;

  /// 데이터 포인트의 화면 좌표 (Rect 내부 기준).
  Offset _pointPos(MoodPoint p, Rect rect) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final dayIdx = (p.date.day - 1).clamp(0, daysInMonth - 1);
    final denom = math.max(1, daysInMonth - 1);
    final x = rect.left + (dayIdx / denom) * rect.width;
    final y = rect.center.dy - (p.score / 100.0) * (rect.height / 2);
    return Offset(x, y);
  }

  Future<void> _openDiary(BuildContext context, WidgetRef ref, String diaryId) async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    try {
      final diary = await ref
          .read(diaryRepositoryProvider)
          .fetchDiaryById(userId, diaryId);
      if (diary == null) return;
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DiaryDetailScreen(diary: diary)),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysInMonth = DateTime(year, month + 1, 0).day;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final chartRect = Rect.fromLTRB(
          _padLeft, _padTop,
          w - _padRight,
          _chartHeight - _padBottom,
        );

        return SizedBox(
          width: w,
          height: _chartHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── 라인 + 글로우 + 점 + 0선 ──
              Positioned.fill(
                child: CustomPaint(
                  painter: _MoodLinePainter(
                    points: data.points,
                    daysInMonth: daysInMonth,
                    chartRect: chartRect,
                  ),
                ),
              ),
              // ── x축 라벨 (1일 / 마지막일) ──
              Positioned(
                left: _padLeft,
                bottom: 4,
                child: _AxisLabel(text: '1일'),
              ),
              Positioned(
                right: _padRight,
                bottom: 4,
                child: _AxisLabel(text: '$daysInMonth일'),
              ),
              // ── 0(평소) 기준선 우측 끝 마커 ──
              Positioned(
                right: _padRight,
                top: (_chartHeight - _padTop - _padBottom) / 2 +
                    _padTop -
                    7,
                child: _AxisLabel(text: '평소', dim: true),
              ),
              // ── 극점 말풍선 ──
              ...data.extremes.map((ex) {
                final p = data.points[ex.index];
                final pos = _pointPos(p, chartRect);
                final aboveLine = _isPositive(p);
                return _Annotation(
                  point: p,
                  pointPos: pos,
                  aboveLine: aboveLine,
                  onTap: () => _openDiary(context, ref, p.diaryId),
                );
              }),
              // ── 데이터 포인트 탭 영역 (말풍선 없는 점도 탭 가능) ──
              ...data.points.map((p) {
                final pos = _pointPos(p, chartRect);
                return Positioned(
                  left: pos.dx - 14,
                  top: pos.dy - 14,
                  width: 28,
                  height: 28,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _openDiary(context, ref, p.diaryId),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _AxisLabel extends StatelessWidget {
  final String text;
  final bool dim;
  const _AxisLabel({required this.text, this.dim = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(dim ? 0.55 : 0.7),
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// 극점 말풍선 — 둥근 알약 형태로 명사 표시 + 데이터 포인트로 향한 짧은 커넥터.
class _Annotation extends StatelessWidget {
  final MoodPoint point;
  final Offset pointPos;
  final bool aboveLine;
  final VoidCallback onTap;

  const _Annotation({
    required this.point,
    required this.pointPos,
    required this.aboveLine,
    required this.onTap,
  });

  static const _gold = Color(0xFFD4A24C);
  static const _goldBright = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final label = point.topNoun ?? '?';
    const bubbleH = 24.0;
    const connectorH = 10.0;
    const totalH = bubbleH + connectorH;

    final top = aboveLine
        ? pointPos.dy - totalH
        : pointPos.dy + 0; // 골짜기는 점 아래로

    // 가로 위치 — 말풍선이 화면 좌우로 안 빠지게 어림 보정
    return Positioned(
      left: pointPos.dx - 40,
      top: top,
      child: SizedBox(
        width: 80,
        height: totalH,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: aboveLine
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _bubble(label),
                    _connector(),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _connector(),
                    _bubble(label),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _bubble(String label) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _gold.withOpacity(0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: _goldBright.withOpacity(0.18),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _connector() {
    return Container(
      width: 1.4,
      height: 10,
      color: _gold.withOpacity(0.55),
    );
  }
}

class _MoodLinePainter extends CustomPainter {
  final List<MoodPoint> points;
  final int daysInMonth;
  final Rect chartRect;

  static const _gold = Color(0xFFD4A24C);
  static const _goldBright = Color(0xFFFFD700);

  _MoodLinePainter({
    required this.points,
    required this.daysInMonth,
    required this.chartRect,
  });

  Offset _pointPos(MoodPoint p) {
    final dayIdx = (p.date.day - 1).clamp(0, daysInMonth - 1);
    final denom = math.max(1, daysInMonth - 1);
    final x = chartRect.left + (dayIdx / denom) * chartRect.width;
    final y =
        chartRect.center.dy - (p.score / 100.0) * (chartRect.height / 2);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ─ 0 (평소) 라인 — 점선 ─
    final zeroY = chartRect.center.dy;
    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const dashW = 4.0;
    const gapW = 4.0;
    double dx = chartRect.left;
    while (dx < chartRect.right) {
      final end = math.min(dx + dashW, chartRect.right);
      canvas.drawLine(Offset(dx, zeroY), Offset(end, zeroY), dashPaint);
      dx += dashW + gapW;
    }

    if (points.isEmpty) return;

    if (points.length == 1) {
      _drawDot(canvas, _pointPos(points.first));
      return;
    }

    // ─ 라인 path ─
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final pos = _pointPos(points[i]);
      if (i == 0) {
        path.moveTo(pos.dx, pos.dy);
      } else {
        path.lineTo(pos.dx, pos.dy);
      }
    }

    // ─ 글로우 (블러) ─
    canvas.drawPath(
      path,
      Paint()
        ..color = _gold.withOpacity(0.45)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ─ 메인 라인 (금색 그라데이션) ─
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [_gold, _goldBright, _gold],
          stops: [0.0, 0.5, 1.0],
        ).createShader(chartRect)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ─ 데이터 포인트 ─
    for (final p in points) {
      _drawDot(canvas, _pointPos(p));
    }
  }

  void _drawDot(Canvas canvas, Offset pos) {
    canvas.drawCircle(
      pos,
      5.5,
      Paint()..color = _goldBright.withOpacity(0.30),
    );
    canvas.drawCircle(
      pos,
      3.2,
      Paint()..color = _goldBright,
    );
    canvas.drawCircle(
      pos,
      1.4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _MoodLinePainter old) {
    return old.points != points ||
        old.daysInMonth != daysInMonth ||
        old.chartRect != chartRect;
  }
}
