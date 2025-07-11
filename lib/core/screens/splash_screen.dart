import 'dart:async';
import 'package:dearlog/core/screens/auth_error_screen.dart';
import 'package:dearlog/core/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dearlog/main.dart';
import '../../user/providers/user_fetch_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    await Future.delayed(const Duration(seconds: 1)); // 스플래시 딜레이

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // 1. userIdProvider에 유저 UID 저장
      ref.read(userIdProvider.notifier).state = currentUser.uid;

      // 2. userProvider 강제 fetch
      final user = await ref.read(userProvider.future);

      // 3. user가 존재하면 MainScreen, 없으면 LoginScreen
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      // 로그인 안 되어 있으면 LoginScreen으로
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('asset/image/logo.png', width: 400, height: 300),
            SizedBox(height: 50),
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 50),
            Text("앱을 시작하는 중입니다...", style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
