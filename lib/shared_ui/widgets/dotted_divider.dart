import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 가로 점선 디바이더.
/// [Divider] 대체 — 다크 톤에서 부드럽게 두 영역을 분리할 때.
class DottedDivider extends StatelessWidget {
  final double dashWidth;
  final double dashGap;
  final double thickness;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const DottedDivider({
    super.key,
    this.dashWidth = 4,
    this.dashGap = 5,
    this.thickness = 1,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        width: double.infinity,
        height: thickness,
        child: CustomPaint(
          painter: _DottedLinePainter(
            color: color ?? Colors.white.withOpacity(0.22),
            dashWidth: dashWidth,
            dashGap: dashGap,
            thickness: thickness,
          ),
        ),
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashGap;
  final double thickness;

  _DottedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.dashGap,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      final end = math.min(x + dashWidth, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter old) {
    return old.color != color ||
        old.dashWidth != dashWidth ||
        old.dashGap != dashGap ||
        old.thickness != thickness;
  }
}
