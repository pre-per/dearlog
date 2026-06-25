import 'package:flutter/material.dart';

import '../models/my_planet.dart';
import '../models/planet_catalog.dart';
import 'layered_image_stack.dart';
import 'nova_view.dart';

/// 베이스 행성 위에 장착한 꾸미기 아이템(고리/별/구름/오브제)을 zIndex 순서로
/// 합성하고, [showNova] 면 행성 위에 Nova(포즈+표정)를 얹는다.
///
/// 좌표는 렌더로 튜닝한 값(행성 중심 기준 비율). v2 행성 원본은 자체 글로우가
/// 있어 씬 폭의 0.86 으로 살짝 여백을 두고 배치한다.
class PlanetScene extends StatelessWidget {
  final MyPlanet planet;
  final PlanetCatalog catalog;
  final double size;
  final bool showNova;

  /// Nova 크기(씬 폭 대비) / 세로 중심 위치(0~1).
  final double novaScale;
  final double novaCenterY;

  const PlanetScene({
    super.key,
    required this.planet,
    required this.catalog,
    required this.size,
    this.showNova = true,
    this.novaScale = 0.52,
    this.novaCenterY = 0.45,
  });

  static const ItemTransform _baseTransform = ItemTransform(scale: 0.86);

  @override
  Widget build(BuildContext context) {
    final base = catalog.basePlanetById(planet.basePlanetType);

    final layers = <PlanetLayer>[
      PlanetLayer(asset: base.asset, transform: _baseTransform, zIndex: 1),
    ];
    for (final id in planet.equippedPlanetItems) {
      final item = catalog.planetItemById(id);
      if (item == null) continue;
      layers.add(
        PlanetLayer(
          asset: item.asset,
          transform: item.transform,
          zIndex: item.zIndex,
        ),
      );
    }

    final novaBox = size * novaScale;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LayeredImageStack(size: size, layers: layers),
          if (showNova)
            Positioned(
              left: 0.5 * size - novaBox / 2,
              top: novaCenterY * size - novaBox / 2,
              width: novaBox,
              height: novaBox,
              child: NovaView(planet: planet, catalog: catalog, size: novaBox),
            ),
        ],
      ),
    );
  }
}
