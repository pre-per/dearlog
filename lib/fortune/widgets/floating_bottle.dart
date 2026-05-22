import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

/// 홈 화면 위에 둥둥 떠다니는 글래스모피즘 유리병.
///
/// - 부모(보통 Positioned.fill)의 크기 안에서 정해진 안전 영역을 무작위로
///   부드럽게 이동 — 통화 버튼을 가리지 않게 위쪽 영역 위주로 분포.
/// - 매 cycle 끝에 새로운 목적지로 갱신해 "둥둥 표류" 느낌을 만든다.
/// - 위·아래로 살짝 흔들거리는 bob 애니메이션이 따로 들어가 있다.
class FloatingBottle extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingBottle({super.key, required this.onTap});

  @override
  State<FloatingBottle> createState() => _FloatingBottleState();
}

class _FloatingBottleState extends State<FloatingBottle>
    with TickerProviderStateMixin {
  // 날렵한 비율 — 폭은 좁히고 높이는 살짝 늘려 와인병/플라스크 같은 실루엣.
  static const double _bottleW = 50;
  static const double _bottleH = 116;

  // 화면 안전 영역 정규화 좌표 (0..1).
  // - x: 좌우로 0.05~0.95 사이 — 너무 가장자리에 붙지 않도록.
  // - y: 0.05~0.55 — 통화 버튼(중앙 하단 부근)을 피해 상단 위주.
  static const double _xMin = 0.05;
  static const double _xMax = 0.95;
  static const double _yMin = 0.05;
  static const double _yMax = 0.55;

  final _rng = Random();

  late final AnimationController _drift;
  late final AnimationController _bob;

  Offset _start = const Offset(0.3, 0.2);
  Offset _end = const Offset(0.7, 0.4);

  @override
  void initState() {
    super.initState();
    _start = _randomNorm();
    _end = _randomNorm();

    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )
      ..addStatusListener(_onDriftStatus)
      ..forward();

    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  void _onDriftStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // 다음 사이클: 현재 종점이 새 시작점이 되고 새로운 종점은 무작위.
    setState(() {
      _start = _end;
      _end = _randomNorm();
    });
    _drift
      ..reset()
      ..forward();
  }

  Offset _randomNorm() {
    final x = _xMin + _rng.nextDouble() * (_xMax - _xMin);
    final y = _yMin + _rng.nextDouble() * (_yMax - _yMin);
    return Offset(x, y);
  }

  @override
  void dispose() {
    _drift.dispose();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth - _bottleW;
        final maxH = constraints.maxHeight - _bottleH;

        return AnimatedBuilder(
          animation: Listenable.merge([_drift, _bob]),
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_drift.value);
            final pos = Offset.lerp(_start, _end, t)!;
            final dx = pos.dx * maxW;
            final bobOffset =
                sin(_bob.value * 2 * pi) * 6.0; // ±6px 위아래 진동
            final dy = pos.dy * maxH + bobOffset;

            // 살짝 흔들리는 회전감. 양 끝에서 1~2도 정도.
            final tilt = sin(_bob.value * 2 * pi) * 0.04;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: dx,
                  top: dy,
                  child: Transform.rotate(
                    angle: tilt,
                    child: _BottleHitbox(onTap: widget.onTap),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BottleHitbox extends StatelessWidget {
  final VoidCallback onTap;
  const _BottleHitbox({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const SizedBox(
        width: _FloatingBottleState._bottleW,
        height: _FloatingBottleState._bottleH,
        child: _GlassBottle(),
      ),
    );
  }
}

/// 글래스모피즘 유리병 도형. 좁고 길쭉한 실루엣 — 어깨선이 살짝 좁아지는
/// 와인 보틀에 가깝게. CustomPaint 없이 Stack + 둥근 컨테이너로만 표현.
class _GlassBottle extends StatelessWidget {
  const _GlassBottle();

  // 도형 비율 상수. 부모 hitbox(_bottleW × _bottleH = 50 × 116) 안에서 사용.
  static const double _corkW = 14;
  static const double _corkH = 9;
  static const double _neckW = 11;
  static const double _neckH = 16;
  static const double _shoulderH = 10;
  static const double _bodyTop = _corkH + _neckH + _shoulderH; // 35
  static const double _bodyRadius = 18;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        // 외곽 글로우 — 살짝 보랏빛.
        Positioned(
          top: _bodyTop - 4,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_bodyRadius + 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA78BFA).withOpacity(0.30),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: const Color(0xFF60A5FA).withOpacity(0.20),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        // 어깨 — 병목에서 본체로 좁아지는 짧은 사다리꼴 느낌의 매듭.
        Positioned(
          top: _corkH + _neckH,
          child: ClipPath(
            clipper: _ShoulderClipper(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: _FloatingBottleState._bottleW,
                height: _shoulderH + 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.20),
                      Colors.white.withOpacity(0.30),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
        // 본체 — backdrop blur + 그라데이션 + 보더.
        Positioned(
          top: _bodyTop,
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_bodyRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_bodyRadius),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.55),
                    width: 1.2,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.32),
                      Colors.white.withOpacity(0.08),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // 좌상단 highlight — 유리 광택.
                    Positioned(
                      top: 6,
                      left: 7,
                      child: Container(
                        width: 10,
                        height: 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.55),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 안쪽 ✨ 별 — 운세가 들어 있다는 힌트.
                    Center(
                      child: Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: Colors.white.withOpacity(0.95),
                        shadows: const [
                          Shadow(
                            color: Color(0x66FFFFFF),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 병목 — 좁고 길쭉.
        Positioned(
          top: _corkH,
          child: Container(
            width: _neckW,
            height: _neckH,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2.5),
                topRight: Radius.circular(2.5),
                bottomLeft: Radius.circular(1.5),
                bottomRight: Radius.circular(1.5),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.0,
              ),
            ),
          ),
        ),
        // 코르크.
        Positioned(
          top: 0,
          child: Container(
            width: _corkW,
            height: _corkH,
            decoration: BoxDecoration(
              color: const Color(0xFFB58A6E),
              borderRadius: BorderRadius.circular(2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 병목 → 본체로 자연스럽게 넓어지는 어깨 곡선용 clipper.
/// 위쪽은 병목 폭(_neckW), 아래쪽은 본체 폭(_bottleW)으로 양옆이 사선.
class _ShoulderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const neckHalf = _GlassBottle._neckW / 2;
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;
    final path = Path()
      ..moveTo(centerX - neckHalf, 0)
      ..lineTo(centerX + neckHalf, 0)
      ..quadraticBezierTo(w * 0.85, h * 0.4, w, h)
      ..lineTo(0, h)
      ..quadraticBezierTo(w * 0.15, h * 0.4, centerX - neckHalf, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
