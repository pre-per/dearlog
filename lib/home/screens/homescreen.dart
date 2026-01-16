import 'dart:ui';

import 'package:dearlog/app.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rippleCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800), // 더 느리게 = 차분
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.99, end: 1.01).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    ); // ✅ 약 ±0.8% 정도
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
              (Route<dynamic> route) => false,
            );
          },
          child: Image.asset(
            'asset/image/logo_white.png',
            width: 120,
            height: 120,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => NoticeScreen()));
            },
            icon: Icon(
              IconsaxPlusBold.notification,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
        ],
      ),

      body: userAsync.when(
        data: (user) {
          if (user == null) return AuthErrorScreen();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    DateFormat('MM월 dd일(E)', 'ko_KR').format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '당신의 목소리를 들을 준비가 되었어요',
                    style: TextStyle(
                      color: Color(0xdfffffff),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 68),
                SizedBox(
                  width: 232,
                  height: 232,
                  child: AnimatedBuilder(
                    animation: _rippleCtrl,
                    builder: (context, _) {
                      final t = _rippleCtrl.value; // 0..1

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // ✅ 파장 4개 (시차 0.00, 0.25, 0.50, 0.75)
                          _RippleRing(
                            t: (t + 0.00) % 1.0,
                            baseSize: 232,
                            minScale: 1.00,
                            maxScale: 1.40,   // 더 멀리 퍼지게
                            maxOpacity: 0.22, // 더 진하게
                            strokeWidth: 1.8, // 조금 더 두껍게
                          ),
                          _RippleRing(
                            t: (t + 0.25) % 1.0,
                            baseSize: 232,
                            minScale: 1.00,
                            maxScale: 1.40,
                            maxOpacity: 0.18,
                            strokeWidth: 1.6,
                          ),
                          _RippleRing(
                            t: (t + 0.50) % 1.0,
                            baseSize: 232,
                            minScale: 1.00,
                            maxScale: 1.40,
                            maxOpacity: 0.15,
                            strokeWidth: 1.4,
                          ),
                          _RippleRing(
                            t: (t + 0.75) % 1.0,
                            baseSize: 232,
                            minScale: 1.00,
                            maxScale: 1.40,
                            maxOpacity: 0.12,
                            strokeWidth: 1.2,
                          ),

                          ScaleTransition(
                            scale: _pulse,
                            child: Image.asset(
                              'asset/image/moon_images/grey_moon.png',
                              width: 232,
                              height: 232,
                            ),
                          ),

                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  width: 350,
                  height: 55,
                  decoration: BoxDecoration(
                    image: DecorationImage(image: AssetImage('asset/image/lang_bubble.png'))
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Text(
                    '디어로그에게 당신의 이야기를 들려주세요',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 19),
                CallStartIconbutton(),
              ],
            ),
          );
        },
        error: (err, _) => Center(child: Text('유저 데이터를 불러오지 못했습니다.\n오류:$err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _RippleRing extends StatelessWidget {
  final double t; // 0..1
  final double baseSize;
  final double minScale;
  final double maxScale;
  final double maxOpacity;
  final double strokeWidth;

  const _RippleRing({
    required this.t,
    required this.baseSize,
    required this.minScale,
    required this.maxScale,
    required this.maxOpacity,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(t);

    final scale = lerpDouble(minScale, maxScale, eased)!;

    // ✅ 초반에는 좀 더 보이고, 끝으로 갈수록 자연스럽게 사라지게
    final opacity = (1.0 - eased) * maxOpacity;

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: baseSize,
            height: baseSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: strokeWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

