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
import '../widgets/nova_view.dart';

/// Nova 꾸미기 — 슬롯별(표정/안테나/가방/손소품/옷) 아이템 장착.
/// MVP 슬롯형: 슬롯당 1개, 다시 누르거나 '없음' 으로 해제.
class NovaDecorateScreen extends ConsumerStatefulWidget {
  final MyPlanet initial;
  final PlanetCatalog catalog;

  const NovaDecorateScreen({
    super.key,
    required this.initial,
    required this.catalog,
  });

  @override
  ConsumerState<NovaDecorateScreen> createState() => _NovaDecorateScreenState();
}

class _NovaDecorateScreenState extends ConsumerState<NovaDecorateScreen> {
  late MyPlanet _draft = widget.initial;
  int _tabIndex = 0;

  static const List<NovaSlot> _slots = NovaSlot.values;

  PlanetCatalog get _catalog => widget.catalog;

  String? _equippedIdIn(NovaSlot slot) {
    for (final id in _draft.equippedNovaItems) {
      final item = _catalog.novaItemById(id);
      if (item != null && item.slot == slot) return id;
    }
    return null;
  }

  void _toggleItem(NovaItem item) {
    final ids = [..._draft.equippedNovaItems];
    final wasSelected = ids.contains(item.id);
    ids.removeWhere((id) {
      final it = _catalog.novaItemById(id);
      return it != null && it.slot == item.slot;
    });
    if (!wasSelected) ids.add(item.id);
    setState(() => _draft = _draft.copyWith(equippedNovaItems: ids));
  }

  void _clearSlot(NovaSlot slot) {
    final ids = [..._draft.equippedNovaItems]..removeWhere((id) {
      final it = _catalog.novaItemById(id);
      return it != null && it.slot == slot;
    });
    setState(() => _draft = _draft.copyWith(equippedNovaItems: ids));
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
    final slot = _slots[_tabIndex];
    final items = _catalog.novaItemsOf(slot);
    final equippedId = _equippedIdIn(slot);
    final previewSize = (MediaQuery.of(context).size.width * 0.66).clamp(
      220.0,
      300.0,
    );

    return BaseScaffold(
      appBar: AppBar(
        title: const Text('Nova 꾸미기'),
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
                child: NovaView(
                  planet: _draft,
                  catalog: _catalog,
                  size: previewSize,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DecorateTabBar(
              labels: [for (final s in _slots) s.label],
              selectedIndex: _tabIndex,
              onSelected: (i) => setState(() => _tabIndex = i),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemCount: items.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return DecorateItemTile(
                      imageAsset: null,
                      label: '없음',
                      selected: equippedId == null,
                      onTap: () => _clearSlot(slot),
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
              ),
            ),
          ],
        ),
      ),
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
