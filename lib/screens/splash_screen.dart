import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dearlog/main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // 2초 후에 HomeScreen으로 이동
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.deepPurple),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.deepPurple),
            SizedBox(height: 10),
            Text("앱을 시작하는 중입니다...", style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
