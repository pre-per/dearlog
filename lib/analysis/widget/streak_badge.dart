import 'package:dearlog/app.dart';
import 'package:flutter/material.dart';

/// 현재 연속 기록 + 최장 연속 기록을 작게 표시하는 가로 배지.
class StreakBadge extends ConsumerWidget {
  const StreakBadge({super.key});

  static const _gold = Color(0xFFFFD700);
  static const _goldSoft = Color(0xFFE8C68A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(diaryStreakProvider);

    if (info.current == 0 && info.longest == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _gold.withOpacity(0.16),
            _goldSoft.withOpacity(0.06),
          ],
        ),
        border: Border.all(color: _gold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${info.current}일 연속 기록 중',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '최장 ${info.longest}일',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
