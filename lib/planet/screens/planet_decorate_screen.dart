import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/base_scaffold.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../models/my_planet.dart';
import '../models/planet_catalog.dart';
import '../providers/planet_providers.dart';
import '../widgets/decorate_item_tile.dart';
import '../widgets/decorate_tab_bar.dart';
import '../widgets/planet_scene.dart';

/// 행성 꾸미기 — 베이스 행성 선택 + 카테고리별(배경/고리/별/위젯) 아이템 장착.
/// MVP 슬롯형: 카테고리당 1개, 다시 누르거나 '없음' 으로 해제.
class PlanetDecorateScreen extends ConsumerStatefulWidget {
  final MyPlanet initial;
  final PlanetCatalog catalog;

  const PlanetDecorateScreen({
    super.key,
    required this.initial,
    required this.catalog,
  });

  @override
  ConsumerState<PlanetDecorateScreen> createState() =>
      _PlanetDecorateScreenState();
}

class _PlanetDecorateScreenState extends ConsumerState<PlanetDecorateScreen> {
  late MyPlanet _draft = widget.initial;
  int _tabIndex = 0;

  // null = '베이스' 탭(행성 본체 선택).
  static const List<PlanetItemCategory?> _tabs = [
    null,
    PlanetItemCategory.ring,
    PlanetItemCategory.star,
    PlanetItemCategory.cloud,
    PlanetItemCategory.object,
  ];

  PlanetCatalog get _catalog => widget.catalog;

  String? _equippedIdIn(PlanetItemCategory category) {
    for (final id in _draft.equippedPlanetItems) {
      final item = _catalog.planetItemById(id);
      if (item != null && item.category == category) return id;
    }
    return null;
  }

  void _setBase(String id) {
    setState(() => _draft = _draft.copyWith(basePlanetType: id));
  }

  void _toggleItem(PlanetItem item) {
    final ids = [..._draft.equippedPlanetItems];
    final wasSelected = ids.contains(item.id);
    ids.removeWhere((id) {
      final it = _catalog.planetItemById(id);
      return it != null && it.category == item.category;
    });
    if (!wasSelected) ids.add(item.id);
    setState(() => _draft = _draft.copyWith(equippedPlanetItems: ids));
  }

  void _clearCategory(PlanetItemCategory category) {
    final ids = [..._draft.equippedPlanetItems]..removeWhere((id) {
      final it = _catalog.planetItemById(id);
      return it != null && it.category == category;
    });
    setState(() => _draft = _draft.copyWith(equippedPlanetItems: ids));
  }

  void _save() {
    final uid = ref.read(userIdProvider);
    if (uid == null || uid.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final repo = ref.read(planetRepositoryProvider);
    final draft = _draft;
    Navigator.of(context).pop();
    // 화장성 저장 — 로컬 캐시에 즉시 반영. 오프라인 hang 방지를 위해 await 안 함.
    unawaited(repo.saveMyPlanet(uid, draft));
  }

  @override
  Widget build(BuildContext context) {
    final category = _tabs[_tabIndex];
    final previewSize = (MediaQuery.of(context).size.width * 0.58).clamp(
      180.0,
      250.0,
    );

    return BaseScaffold(
      appBar: AppBar(
        title: const Text('행성 꾸미기'),
        centerTitle: true,
        actions: [_SaveAction(onTap: _save)],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: previewSize,
              child: Center(
                child: PlanetScene(
                  planet: _draft,
                  catalog: _catalog,
                  size: previewSize,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DecorateTabBar(
              labels: [for (final c in _tabs) c?.label ?? '베이스'],
              selectedIndex: _tabIndex,
              onSelected: (i) => setState(() => _tabIndex = i),
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  category == null
                      ? _buildBaseGrid()
                      : _buildPlanetItemGrid(category),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridView({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }

  Widget _buildBaseGrid() {
    final bases = _catalog.basePlanets;
    return _gridView(
      itemCount: bases.length,
      itemBuilder: (context, i) {
        final base = bases[i];
        return DecorateItemTile(
          imageAsset: base.thumb,
          label: base.name,
          selected: _draft.basePlanetType == base.id,
          onTap: () => _setBase(base.id),
        );
      },
    );
  }

  Widget _buildPlanetItemGrid(PlanetItemCategory category) {
    final items = _catalog.planetItemsOf(category);
    final equippedId = _equippedIdIn(category);
    return _gridView(
      itemCount: items.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return DecorateItemTile(
            imageAsset: null,
            label: '없음',
            selected: equippedId == null,
            onTap: () => _clearCategory(category),
          );
        }
        final item = items[i - 1];
        return DecorateItemTile(
          imageAsset: item.thumb,
          label: item.name,
          selected: equippedId == item.id,
          onTap: () => _toggleItem(item),
        );
      },
    );
  }
}

class _SaveAction extends StatelessWidget {
  final VoidCallback onTap;

  const _SaveAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: onTap,
        child: const Text(
          '저장',
          style: TextStyle(
            color: Color(0xFFFFD27A),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
