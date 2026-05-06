import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analysis_providers.dart';
import '../../diary/providers/diary_providers.dart';
import '../../diary/screens/diary_detail_screen.dart';
import '../../shared_ui/utils/planet_asset_mapper.dart';
import 'keyword_color_palette.dart';

void showKeywordDetailSheet(BuildContext context, KeywordMapItem item) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _KeywordDetailSheet(item: item),
  );
}

class _KeywordDetailSheet extends ConsumerWidget {
  final KeywordMapItem item;
  const _KeywordDetailSheet({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glow = keywordGlowColor(item.emotion);
    final planet = planetAssetForEmotion(item.emotion);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131b28),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.08)),
              left: BorderSide(color: Colors.white.withOpacity(0.08)),
              right: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.only(top: 14, bottom: 28),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _MiniPlanet(planet: planet, glow: glow),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: Text(
                                  item.word,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${item.count}번',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _EmotionChips(counts: item.emotionCounts),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  '이 키워드가 등장한 순간',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (item.sources.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '관련 인용문을 찾지 못했어요.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ...item.sources.map(
                    (src) => _QuoteTile(src: src, onTap: () => _openDiary(context, ref, src.diaryId)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openDiary(BuildContext context, WidgetRef ref, String diaryId) {
    final list = ref.read(diaryStreamProvider).asData?.value;
    if (list == null) return;
    final match = list.where((e) => e.id == diaryId).toList();
    if (match.isEmpty) return;
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DiaryDetailScreen(diary: match.first)),
    );
  }
}

class _EmotionChips extends StatelessWidget {
  final Map<String, int> counts;
  const _EmotionChips({required this.counts});

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) {
      return const SizedBox.shrink();
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: entries.map((e) {
        final color = keywordGlowColor(e.key);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${e.key} ${e.value}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MiniPlanet extends StatelessWidget {
  final String planet;
  final Color glow;
  const _MiniPlanet({required this.planet, required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: glow.withOpacity(0.55), blurRadius: 16),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              planet,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1B2433)),
            ),
            Container(color: Colors.black.withOpacity(0.45)),
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: glow, width: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteTile extends StatelessWidget {
  final DiaryRef src;
  final VoidCallback onTap;
  const _QuoteTile({required this.src, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dateLabel(src.date),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.white.withOpacity(0.62),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '"${src.quote}"',
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}
