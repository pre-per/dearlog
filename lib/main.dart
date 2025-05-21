import 'package:dearlog/firebase_options.dart';
import 'package:dearlog/screens/home/homescreen.dart';
import 'package:dearlog/screens/profile/profile_screen.dart';
import 'package:dearlog/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/match/match_list_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
          backgroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        scaffoldBackgroundColor: Colors.white,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
        ),
        bottomAppBarTheme: BottomAppBarTheme(
          color: Colors.white,
        ),
        fontFamily: 'Pretendard',
      ),
      home: SplashScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    MatchListScreen(),
    SettingsScreen(),
    ProfileScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(IconsaxPlusBold.home_1), label: '홈'),
          BottomNavigationBarItem(icon: Icon(IconsaxPlusBold.heart), label: '추천'),
          BottomNavigationBarItem(icon: Icon(IconsaxPlusBold.setting_2), label: '설정'),
          BottomNavigationBarItem(icon: Icon(IconsaxPlusBold.user), label: '내 정보'),
        ],
      ),
    );
  }
}
