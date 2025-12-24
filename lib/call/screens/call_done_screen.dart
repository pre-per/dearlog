import 'dart:ui';

import 'package:dearlog/app.dart';

class CallDoneScreen extends StatelessWidget {
  final DiaryEntry diary;
  const CallDoneScreen({super.key, required this.diary});

  @override
  Widget build(BuildContext context) {

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
              child: Text(
                '홈으로',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                'asset/image/moon_images/${planetBaseNameMap[diary.emotion] ?? 'grey_moon'}.png',
                width: 232,
                height: 232,
              ),
              const SizedBox(height: 40),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0x1affffff),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('대화가 잘 기록되었어요!', style: TextStyle(color: Colors.white, fontSize: 16),),
                            const Text('이제 오늘의 일기를 같이 확인해볼까요?', style: TextStyle(color: Colors.white, fontSize: 16),),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => MainScreen()),
                        (route) => false, // 🔥 모든 기존 라우트 제거
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiaryDetailScreen(diary: diary),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xff313345),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: const Text('오늘의 일기 확인하기', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),),
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
