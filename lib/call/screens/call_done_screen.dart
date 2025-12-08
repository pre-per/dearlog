import 'package:dearlog/app.dart';

class CallDoneScreen extends StatelessWidget {
  const CallDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 200),
              Image.asset(
                'asset/image/moon_images/grey_moon.png',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('대화가 잘 기록되었어요!', style: TextStyle(color: Colors.white, fontSize: 16),),
                        const Text('이제 오늘의 행성을 같이 채워볼까요?', style: TextStyle(color: Colors.white, fontSize: 16),),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SelectPlanetScreen())),
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
                      child: const Text('네! 준비됐어요', style: TextStyle(color: Colors.white, fontSize: 16),),
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
