import 'package:dearlog/app.dart';

class SelectPlanetDoneScreen extends ConsumerWidget {
  const SelectPlanetDoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedPlanetProvider);
    final selectedShape = ref.watch(selectedPlanetShapeProvider);

    final planets = ['슬픔', '분노', '평온', '기쁨', '행복'];
    final selectedLabel = planets[selectedIndex];

    // 감정 → 베이스 파일 이름
    final baseName = planetBaseNameMap[selectedLabel]!;

    final isRing = selectedShape == PlanetShape.ring;

    return BaseScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => MainScreen()),
                  (route) => false,
              );
            },
            child: SizedBox(
              height: 30,
              child: Text('홈으로', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              Image.asset(
                'asset/image/moon_images/${baseName}${isRing ? '_rounded' : ''}.png',
                width: 232,
                height: 232,
              ),
              const SizedBox(height: 40),
              Container(
                width: 327,
                height: 67,
                decoration: BoxDecoration(
                  color: Color(0x1affffff),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: const Text(
                      '11월 7일(금) 행성이 생성되었어요!',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  final DiaryEntry diary = ref.read(latestDiaryProvider)!;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => MainScreen()),
                        (route) => false, // 🔥 모든 기존 라우트 제거
                  );
                  // 2) 그 위에 바로 방금 만든 일기 상세 화면 올리기
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiaryDetailScreen(diary: diary),
                    ),
                  );
                },
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
                      child: const Text(
                        '일기장 바로가기',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
