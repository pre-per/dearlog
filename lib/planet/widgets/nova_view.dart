import 'package:flutter/material.dart';

import '../models/my_planet.dart';
import '../models/planet_catalog.dart';
import 'layered_image_stack.dart';

/// Nova 렌더 — 포즈(바디)를 채우고 그 위에 표정을 머리 위치에 얹는다.
///
/// v2 포즈는 안테나·가방·소품이 포함된 완성형이라 바디 자체가 곧 Nova 다. 표정은
/// 포즈 머리 중심에 맞춘 오버레이(렌더로 튜닝). zIndex: 포즈(0) < 표정(9).
class NovaView extends StatelessWidget {
  final MyPlanet planet;
  final PlanetCatalog catalog;
  final double size;

  const NovaView({
    super.key,
    required this.planet,
    required this.catalog,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final layers = <PlanetLayer>[];
    var hasPose = false;
    for (final id in planet.equippedNovaItems) {
      final item = catalog.novaItemById(id);
      if (item == null) continue;
      if (item.slot == NovaSlot.pose) hasPose = true;
      layers.add(
        PlanetLayer(
          asset: item.asset,
          transform: item.transform,
          zIndex: item.zIndex,
        ),
      );
    }

    // 포즈가 없으면 기본 포즈로 폴백(바디가 비지 않게).
    if (!hasPose) {
      final pose = catalog.defaultPose;
      layers.add(
        PlanetLayer(
          asset: pose.asset,
          transform: pose.transform,
          zIndex: pose.zIndex,
        ),
      );
    }

    return LayeredImageStack(size: size, layers: layers);
  }
}
