import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/community_providers.dart';
import '../utils/emotion_groups.dart';

/// 피드 상단의 감정 그룹 필터. 가로 스크롤되는 칩 행.
///
/// 첫 칩 "전체" 는 필터 해제. 나머지는 5개 감정 그룹 — 한 번에 하나만 선택 가능.
class EmotionFilterBar extends ConsumerWidget {
  const EmotionFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(communityEmotionFilterProvider);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: '전체',
            selected: selected == null,
            onTap: () =>
                ref.read(communityEmotionFilterProvider.notifier).state = null,
          ),
          for (final g in emotionGroups) ...[
            const SizedBox(width: 8),
            _Chip(
              label: g.label,
              moonAsset: 'asset/image/moon_images/${g.moonAsset}.png',
              selected: selected == g.key,
              onTap: () => ref
                  .read(communityEmotionFilterProvider.notifier)
                  .state = (selected == g.key ? null : g.key),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String? moonAsset;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.moonAsset,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFFFFD700).withOpacity(0.18)
        : Colors.white.withOpacity(0.06);
    final borderColor = selected
        ? const Color(0xFFFFD700)
        : Colors.white.withOpacity(0.15);
    final textColor =
        selected ? const Color(0xFFFFD700) : Colors.white.withOpacity(0.85);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (moonAsset != null) ...[
              Image.asset(moonAsset!, width: 18, height: 18),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
