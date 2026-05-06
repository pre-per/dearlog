import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await RemoteConfigService().initialize();
  await _requestNotificationPermission();
  await initializeDateFormatting('ko_KR', null);
  await LocalNotificationService.instance.init();
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: notificationNavigatorKey,
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          iconTheme: const IconThemeData(color: Colors.white),
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        scaffoldBackgroundColor: Colors.transparent,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
        ),
        bottomAppBarTheme: BottomAppBarThemeData(color: Colors.grey[50]),
        // ✅ 스낵바: 어두운 배경 + 명시적 흰색 텍스트로 통일.
        //    (Material 3 default는 dark theme에서 반전 색상을 써서, 우리가 backgroundColor만
        //     어둡게 덮어쓰면 글씨가 어두운 색이 되어 안 보이는 문제가 있었음.)
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1E1E2E),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
            fontFamily: 'GowunBatang',
            fontWeight: FontWeight.w500,
          ),
          behavior: SnackBarBehavior.floating,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        fontFamily: 'GowunBatang',
        brightness: Brightness.dark,
      ),
      home: SplashScreen(),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  final String? snackMessage;

  const MainScreen({
    super.key,
    this.snackMessage,
  });

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _screens = [
    HomeScreen(),
    DiaryMainScreen(),
    AnalysisScreen(),
    SettingMainScreen(),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = widget.snackMessage;
      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.grey[600],
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 콜드 스타트 시 큐잉된 알림 페이로드 처리
      _handlePendingNotificationPayload();
    });

    // 포그라운드/백그라운드 탭 페이로드 구독
    NotificationCenter.pendingPayload.addListener(_handlePendingNotificationPayload);
  }

  @override
  void dispose() {
    NotificationCenter.pendingPayload.removeListener(_handlePendingNotificationPayload);
    super.dispose();
  }

  Future<void> _handlePendingNotificationPayload() async {
    final payload = NotificationCenter.consume();
    if (payload == null) return;
    debugPrint('[알림] dispatch payload=$payload');

    if (payload == NotificationPayload.dailyReminder) {
      // 일일 리마인더 → 일기장 탭으로 전환
      ref.read(MainIndexProvider.notifier).state = 1;
      return;
    }

    final diaryId = NotificationPayload.extractDiaryId(payload);
    if (diaryId != null) {
      final userId = ref.read(userIdProvider);
      if (userId == null) return;
      try {
        final diary = await ref
            .read(diaryRepositoryProvider)
            .fetchDiaryById(userId, diaryId);
        if (diary == null) {
          debugPrint('[알림] diaryId=$diaryId 일기 없음 — dispatch 스킵');
          return;
        }
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DiaryDetailScreen(diary: diary)),
        );
      } catch (e) {
        debugPrint('[알림] dispatch 실패: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int currentIndex = ref.watch(MainIndexProvider);
    return BaseScaffold(
      body: _screens[currentIndex],
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX:25.0, sigmaY: 25.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              currentIndex: currentIndex,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              onTap:
                  (index) => setState(
                    () => ref.read(MainIndexProvider.notifier).state = index,
                  ),
              items: [
                BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                    'asset/icons/navigation/planet.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                  ),
                  activeIcon: SvgPicture.asset(
                    'asset/icons/navigation/planet.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                  label: '홈',
                ),
                BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                    'asset/icons/navigation/moon_stars.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                  ),
                  activeIcon: SvgPicture.asset(
                    'asset/icons/navigation/moon_stars.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                  label: '일기장',
                ),
                BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                    'asset/icons/navigation/analytics.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                  ),
                  activeIcon: SvgPicture.asset(
                    'asset/icons/navigation/analytics.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                  label: '분석',
                ),
                BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                    'asset/icons/navigation/user.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                  ),
                  activeIcon: SvgPicture.asset(
                    'asset/icons/navigation/user.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                  label: '마이',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _requestNotificationPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  try {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('[NOTI] FCM 권한 상태: ${settings.authorizationStatus}');

    // ✅ 디버그 편의 — APNs/FCM 토큰 로그 (운영에서는 sentry 등으로 옮기는 게 안전)
    final token = await messaging.getToken();
    print('[NOTI] FCM token=${token == null ? "null" : "${token.substring(0, 16)}..."}');
  } catch (e, st) {
    print('[NOTI] ❌ FCM 권한 요청 실패: $e');
    print('[NOTI] stack: $st');
  }
}
