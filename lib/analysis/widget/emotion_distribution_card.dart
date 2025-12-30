import 'package:dearlog/app.dart';

class EmotionDistributionCard extends ConsumerWidget {
  const EmotionDistributionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distAsync = ref.watch(weeklyEmotionDistProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('감정 분포',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          distAsync.when(
            data: (items) {
              // 1) planetBaseNameMap을 이용해 emotion → planetBase 매핑
              final Map<String, int> planetPercentMap = {};

              for (final it in items) {
                final planetBase = planetBaseNameMap[it.emotion];
                if (planetBase == null) continue;

                planetPercentMap[planetBase] =
                    (planetPercentMap[planetBase] ?? 0) + it.percent;
              }

              // 2) 항상 5개 행성 만들기 (없으면 0%)
              final allPlanets = {
                'blue_moon',
                'green_moon',
                'orange_moon',
                'funny_moon',
                'happy_moon',
              };

              final filled = allPlanets.map((base) {
                return PlanetDistItem(
                  planetBase: base,
                  percent: planetPercentMap[base] ?? 0,
                );
              }).toList();

              // 3) 퍼센트 내림차순 정렬
              filled.sort((a, b) => b.percent.compareTo(a.percent));

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: filled.map((it) {
                  final asset =
                      'asset/image/moon_images/${it.planetBase}.png';

                  return _DistItem(
                    asset: asset,
                    emotion: _planetLabel(it.planetBase),
                    percent: it.percent,
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text('오류: $e', style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _DistItem extends StatelessWidget {
  final String asset;
  final String emotion;
  final int percent;

  const _DistItem({
    required this.asset,
    required this.emotion,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          ClipOval(child: Image.asset(asset, width: 44, height: 44, fit: BoxFit.cover)),
          const SizedBox(height: 8),
          Text(emotion, style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(height: 2),
          Text('($percent%)', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

String _planetLabel(String base) {
  switch (base) {
    case 'blue_moon':
      return '우울';
    case 'green_moon':
      return '안정';
    case 'orange_moon':
      return '분노';
    case 'funny_moon':
      return '기쁨';
    case 'happy_moon':
      return '행복';
    default:
      return '';
  }
}


class PlanetDistItem {
  final String planetBase; // blue_moon, green_moon ...
  final int percent;

  PlanetDistItem({
    required this.planetBase,
    required this.percent,
  });
}

