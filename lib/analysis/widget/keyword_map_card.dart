import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analysis_providers.dart';
import 'keyword_bubble.dart';
import 'keyword_detail_sheet.dart';

class KeywordMapCard extends ConsumerWidget {
  const KeywordMapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(monthlyKeywordMapProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF101828),
              Color(0xFF0B121C),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: asyncItems.when(
          loading: () => const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
            ),
          ),
          error: (_, __) => const Center(
            child: Text(
              '키워드를 불러오지 못했어요.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          data: (items) {
            if (items.isEmpty) return const _EmptyKeywordMap();
            return _KeywordMapField(items: items);
          },
        ),
      ),
    );
  }
}

class _EmptyKeywordMap extends StatelessWidget {
  const _EmptyKeywordMap();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bubble_chart_outlined,
              size: 36,
              color: Colors.white.withOpacity(0.35),
            ),
            const SizedBox(height: 12),
            Text(
              '이 달의 첫 통화를 기다리고 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '통화를 마치면 그날의 감정과 키워드가 행성처럼 떠올라요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placed {
  final KeywordMapItem item;
  final Offset center;
  final double radius;
  _Placed({required this.item, required this.center, required this.radius});
}

class _KeywordMapField extends StatelessWidget {
  final List<KeywordMapItem> items;
  const _KeywordMapField({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final placed = _packBubbles(items, c.maxWidth, c.maxHeight);
        return ClipRect(
          child: Stack(
            children: placed.map((p) {
              return Positioned(
                left: p.center.dx - p.radius,
                top: p.center.dy - p.radius,
                child: KeywordBubble(
                  item: p.item,
                  radius: p.radius,
                  onTap: () => showKeywordDetailSheet(context, p.item),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

List<_Placed> _packBubbles(List<KeywordMapItem> items, double w, double h) {
  if (items.isEmpty || w <= 0 || h <= 0) return const [];

  final shorter = math.min(w, h);
  final r3 = shorter * 0.20;
  final r1 = math.max(20.0, shorter * 0.092);
  final r2 = (r1 + r3) / 2;

  final placed = <_Placed>[];
  final cx = w / 2;
  final cy = h / 2;
  const padding = 5.0;
  int size2Used = 0;

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final double r;
    if (i == 0 && item.count >= 3) {
      r = r3;
    } else if (item.count >= 2 && size2Used < 3) {
      r = r2;
      size2Used++;
    } else {
      r = r1;
    }
    Offset chosen = Offset(cx, cy);
    bool found = false;

    if (placed.isEmpty) {
      if (cx - r >= 0 && cx + r <= w && cy - r >= 0 && cy + r <= h) {
        chosen = Offset(cx, cy);
        found = true;
      }
    } else {
      const dTheta = math.pi / 24;
      const dRho = 0.6;
      double theta = 0;
      for (int i = 0; i < 6000; i++) {
        theta += dTheta;
        final rho = dRho * theta;
        final x = cx + rho * math.cos(theta);
        final y = cy + rho * math.sin(theta);
        if (x - r < 0 || x + r > w || y - r < 0 || y + r > h) continue;
        bool collides = false;
        for (final p in placed) {
          final d = (p.center - Offset(x, y)).distance;
          if (d < p.radius + r + padding) {
            collides = true;
            break;
          }
        }
        if (!collides) {
          chosen = Offset(x, y);
          found = true;
          break;
        }
      }
    }

    if (found) {
      placed.add(_Placed(item: item, center: chosen, radius: r));
    }
  }

  return placed;
}
