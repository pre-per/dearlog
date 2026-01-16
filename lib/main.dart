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
      if (msg == null) return;

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
    });
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

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('🔔 권한 상태: ${settings.authorizationStatus}');
}
