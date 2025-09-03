import 'package:dearlog/firebase_options.dart';
import 'package:dearlog/app/navigation/mainscreen_index_provider.dart';
import 'package:dearlog/analytics/screens/analytics_main_screen.dart';
import 'package:dearlog/diary/screens/diary_main_screen.dart';
import 'package:dearlog/home/screens/homescreen.dart';
import 'package:dearlog/settings/screens/setting_main_screen.dart';
import 'package:dearlog/auth/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/remote_config_service.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:unicons/unicons.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await RemoteConfigService().initialize();
  await _requestNotificationPermission();
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
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        scaffoldBackgroundColor: Colors.grey.shade50,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
        ),
        bottomAppBarTheme: BottomAppBarTheme(
          color: Colors.grey[50],
        ),
        fontFamily: 'Pretendard',
      ),
      home: SplashScreen(),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _screens = [
    HomeScreen(),
    DiaryMainScreen(),
    AnalyticsMainScreen(),
    SettingMainScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    int currentIndex = ref.watch(MainIndexProvider);
    return Scaffold(
      body: _screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => ref.read(MainIndexProvider.notifier).state = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(IconsaxPlusBold.home_2), label: '홈'),
          BottomNavigationBarItem(icon: Icon(IconsaxPlusBold.note_text), label: '일기장'),
          BottomNavigationBarItem(icon: Icon(UniconsSolid.chart), label: '분석'),
          BottomNavigationBarItem(icon: Icon(IconsaxPlusBold.user), label: '내 정보'),
        ],
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