import 'package:dearlog/app.dart';

class SelectPlanetScreen extends ConsumerWidget {
  const SelectPlanetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedPlanetProvider);
    final selectedShape = ref.watch(selectedPlanetShapeProvider);

    final planets = ['슬픔', '분노', '평온', '기쁨', '행복'];
    final selectedLabel = planets[selectedIndex];

    // 감정 → 베이스 파일 이름
    final baseName = planetBaseNameMap[selectedLabel]!;

    final isRing = selectedShape == PlanetShape.ring;

    final topImagePath =
        'asset/image/moon_images/${baseName}${isRing ? '_rounded' : ''}.png';

    return BaseScaffold(
      body: Column(
        children: [
          const SizedBox(height: 120),
          Image.asset(topImagePath, width: 232, height: 232),
          Spacer(),
          Container(
            height: 416,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0x1affffff),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 29,
                vertical: 24,
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      '    행성의 색상',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(planets.length, (i) {
                      final isSelected = i == selectedIndex;
                      return Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              ref
                                  .read(selectedPlanetProvider.notifier)
                                  .state = i;
                            },
                            child: PlanetItem(
                              label: planets[i],
                              isSelected: isSelected,
                            ),
                          ),
                          if (i != planets.length - 1)
                            const SizedBox(width: 12), // 🔥 마지막 제외하고 간격 12
                        ],
                      );
                    }),
                  ),
                  const SizedBox(height: 33),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      '    행성의 모양',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(width: 15),
                      _ShapeItem(
                        label: '원형',
                        isSelected: selectedShape == PlanetShape.circle,
                        onTap: () {
                          ref
                              .read(selectedPlanetShapeProvider.notifier)
                              .state = PlanetShape.circle;
                        },
                      ),
                      const SizedBox(width: 12),
                      _ShapeItem(
                        label: '고리형',
                        isSelected: selectedShape == PlanetShape.ring,
                        onTap: () {
                          ref
                              .read(selectedPlanetShapeProvider.notifier)
                              .state = PlanetShape.ring;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SelectPlanetDoneScreen())),
                    child: Container(
                      width: 327,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Color(0xff313345),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: const Text('완료', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlanetItem extends StatelessWidget {
  final String label;
  final bool isSelected;

  const PlanetItem({super.key, required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final imagePath =
        'asset/image/moon_images/${planetBaseNameMap[label] ?? 'grey_moon'}.png'; // 🔥 label → 이미지 매핑 불러오기

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // 행성 이미지
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // 체크 아이콘
            if (isSelected)
              const Icon(Icons.check_circle, size: 26, color: Colors.white),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 16)),
      ],
    );
  }
}

class _ShapeItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShapeItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          label == '원형' ? const SizedBox(height: 10) : const SizedBox(height: 0),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: label == '원형' ? 50 : 65,
                height: label == '원형' ? 50 : 65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  label == '원형'
                      ? 'asset/image/moon_images/grey_moon.png'
                      : 'asset/image/moon_images/grey_moon_rounded.png',
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, size: 20, color: Colors.white),
            ],
          ),
          label == '원형' ? const SizedBox(height: 10) : const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// 감정 → 파일 이름의 베이스
const planetBaseNameMap = {
  '슬픔': 'blue_moon',
  '분노': 'orange_moon',
  '평온': 'green_moon',
  '기쁨': 'funny_moon',
  '행복': 'happy_moon',
};
