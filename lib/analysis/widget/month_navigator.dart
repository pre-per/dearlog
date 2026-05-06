import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analysis_providers.dart';

class MonthNavigator extends ConsumerWidget {
  const MonthNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMonthProvider);
    final canGoNext = !selected.isCurrent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ArrowButton(
          icon: Icons.chevron_left,
          onTap: () {
            ref.read(selectedMonthProvider.notifier).state = selected.previous;
          },
        ),
        const SizedBox(width: 16),
        Column(
          children: [
            Text(
              selected.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              selected.isCurrent ? '이번 달의 기분 맵' : '추억 보기',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        _ArrowButton(
          icon: Icons.chevron_right,
          enabled: canGoNext,
          onTap: () {
            if (!canGoNext) return;
            ref.read(selectedMonthProvider.notifier).state = selected.next;
          },
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _ArrowButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.white.withOpacity(0.85) : Colors.white.withOpacity(0.2);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white.withOpacity(0.06) : Colors.transparent,
          border: Border.all(
            color: enabled
                ? Colors.white.withOpacity(0.12)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}
