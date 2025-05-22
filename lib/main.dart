import 'package:dearlog/firebase_options.dart';
import 'package:dearlog/providers/mainscreen_index_provider.dart';
import 'package:dearlog/screens/chat/chat_home_screen.dart';
import 'package:dearlog/screens/home/homescreen.dart';
import 'package:dearlog/screens/profile/profile_screen.dart';
import 'package:dearlog/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/match/match_list_screen.dart';
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

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _screens = [
    HomeScreen(),
    ChatHomeScreen(),
    MatchListScreen(),
    ProfileScreen()
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
          BottomNavigationBarItem(icon: Icon(IconsaxPlusBold.home_1), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.call), label: '통화'),
          BottomNavigationBarItem(icon: Icon(IconsaxPlusBold.heart), label: '매칭'),
          BottomNavigationBarItem(icon: Icon(IconsaxPlusBold.user), label: '내 정보'),
        ],
      ),
    );
  }
}
