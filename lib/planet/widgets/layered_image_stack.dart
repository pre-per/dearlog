import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/planet_catalog.dart';

/// 한 장의 풀캔버스 레이어.
class PlanetLayer {
  final String asset;
  final ItemTransform transform;
  final int zIndex;

  const PlanetLayer({
    required this.asset,
    required this.transform,
    required this.zIndex,
  });
}

/// 정사각 캔버스에 풀캔버스 PNG 레이어들을 zIndex 순서로 쌓는다.
///
/// 각 PNG 는 1080²/1024² 풀캔버스에 합성 위치로 그려져 있으므로, scale=1·중심
/// (0.5,0.5)이면 캔버스를 꽉 채우고, star/widget 처럼 transform 이 있으면 중심을
/// (x,y)로 옮기고 [size]·scale 크기로 축소해 작은 오브젝트로 배치한다.
class LayeredImageStack extends StatelessWidget {
  final double size;
  final List<PlanetLayer> layers;

  const LayeredImageStack({
    super.key,
    required this.size,
    required this.layers,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...layers]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [for (final layer in sorted) _positioned(layer)],
      ),
    );
  }

  Widget _positioned(PlanetLayer layer) {
    final t = layer.transform;
    final boxSize = size * t.scale;
    final left = t.x * size - boxSize / 2;
    final top = t.y * size - boxSize / 2;

    Widget image = Image.asset(
      layer.asset,
      width: boxSize,
      height: boxSize,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );

    if (t.rotation != 0) {
      image = Transform.rotate(angle: t.rotation * math.pi / 180, child: image);
    }

    return Positioned(
      left: left,
      top: top,
      width: boxSize,
      height: boxSize,
      child: image,
    );
  }
}
