import 'package:dearlog/app.dart';
import 'package:flutter/material.dart';

/// 직전 6개월에 없었던, 이 달에 처음 등장한 명사 키워드.
class NewKeywordsCard extends ConsumerWidget {
  const NewKeywordsCard({super.key});

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(monthlyStatsProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fiber_new_rounded, color: _gold, size: 18),
              const SizedBox(width: 6),
              Text(
                '새로 등장한 키워드',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '직전 6개월엔 없던 단어들',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          asyncStats.when(
            loading: () => const SizedBox(height: 40),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) {
              final keywords = stats.newKeywords;
              if (keywords.isEmpty) {
                return Text(
                  '이 달엔 새로 등장한 단어가 없어요',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontFamily: 'GowunBatang',
                  ),
                );
              }
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: keywords.take(15).map(_pill).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _pill(String word) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _gold.withOpacity(0.4)),
      ),
      child: Text(
        word,
        style: const TextStyle(
          color: _gold,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          fontFamily: 'GowunBatang',
        ),
      ),
    );
  }
}
