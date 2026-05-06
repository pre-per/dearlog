import 'package:dearlog/app.dart';
import 'package:flutter/material.dart';

/// 활동-감정 상관관계 — Top 3 (긍정 영향) / Bottom 3 (부정 영향) 키워드.
class KeywordImpactCard extends ConsumerWidget {
  const KeywordImpactCard({super.key});

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
              const Icon(Icons.insights_rounded, color: _gold, size: 18),
              const SizedBox(width: 6),
              Text(
                '나를 띄운 것 · 무겁게 한 것',
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
            '같은 단어가 등장한 날들의 평균 기분 점수',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          asyncStats.when(
            loading: () => const _Loading(),
            error: (_, __) => const _ErrorView(),
            data: (stats) {
              final hasAny = stats.topImpacts.isNotEmpty ||
                  stats.bottomImpacts.isNotEmpty;
              if (!hasAny) {
                return _Hint(
                  text: stats.diaryCount < 3
                      ? '일기가 더 쌓이면 패턴이 보일 거예요'
                      : '이 달엔 두드러진 패턴이 없었어요',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stats.topImpacts.isNotEmpty)
                    _Group(
                      label: '띄운 것',
                      icon: Icons.arrow_upward_rounded,
                      color: const Color(0xFF4ADE80),
                      items: stats.topImpacts,
                    ),
                  if (stats.topImpacts.isNotEmpty &&
                      stats.bottomImpacts.isNotEmpty)
                    const SizedBox(height: 14),
                  if (stats.bottomImpacts.isNotEmpty)
                    _Group(
                      label: '무겁게 한 것',
                      icon: Icons.arrow_downward_rounded,
                      color: const Color(0xFFFF7B7B),
                      items: stats.bottomImpacts,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<KeywordImpact> items;

  const _Group({
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((it) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ImpactRow(item: it, accent: color),
            )),
      ],
    );
  }
}

class _ImpactRow extends StatelessWidget {
  final KeywordImpact item;
  final Color accent;

  const _ImpactRow({required this.item, required this.accent});

  @override
  Widget build(BuildContext context) {
    final scoreLabel =
        '${item.avgMood >= 0 ? '+' : ''}${item.avgMood.round()}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${item.count}회',
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withOpacity(0.5)),
            ),
            child: Text(
              scoreLabel,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          text,
          style: TextStyle(
              color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 80,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation(KeywordImpactCard._gold),
            ),
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '데이터를 불러오지 못했어요',
          style: TextStyle(
              color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
      );
}
