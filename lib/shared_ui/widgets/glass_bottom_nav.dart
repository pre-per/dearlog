import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 글래스모피즘 플로팅 바텀 내비게이션.
/// 머티리얼 [BottomNavigationBar] 대체 — pill 형태로 화면 하단에 떠 있다.
/// 선택된 탭은 슬라이딩 indicator pill 이 따라 움직인다.
class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavItem> items;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  static const double _outerRadius = 30;
  static const double _innerRadius = 22;
  static const double _indicatorInset = 4;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_outerRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withOpacity(0.62),
                    Colors.black.withOpacity(0.48),
                  ],
                ),
                borderRadius: BorderRadius.circular(_outerRadius),
                border: Border.all(
                  color: Colors.white.withOpacity(0.10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.40),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth =
                      constraints.maxWidth / items.length;
                  return SizedBox(
                    height: 52,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          left: itemWidth * currentIndex + _indicatorInset,
                          top: _indicatorInset,
                          bottom: _indicatorInset,
                          width: itemWidth - _indicatorInset * 2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius:
                                  BorderRadius.circular(_innerRadius),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.32),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (int i = 0; i < items.length; i++)
                              Expanded(
                                child: _GlassNavItem(
                                  item: items[i],
                                  selected: currentIndex == i,
                                  onTap: () => onTap(i),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassNavItem {
  final String? svgPath;
  final IconData? icon;
  final String label;

  const GlassNavItem({
    this.svgPath,
    this.icon,
    required this.label,
  }) : assert(svgPath != null || icon != null,
            'svgPath 또는 icon 중 하나는 필요');
}

class _GlassNavItem extends StatelessWidget {
  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _GlassNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? Colors.white : Colors.white.withOpacity(0.45);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        // 아이콘 시각 무게가 위에 쏠려서, 살짝 아래로 내려야 광학적 중앙이 맞는다.
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: _buildIcon(color),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                height: 1.0,
                fontWeight:
                    selected ? FontWeight.w800 : FontWeight.w500,
                fontFamily: 'GowunBatang',
                letterSpacing: 0.1,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    if (item.svgPath != null) {
      return SvgPicture.asset(
        item.svgPath!,
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(item.icon, size: 22, color: color);
  }
}
