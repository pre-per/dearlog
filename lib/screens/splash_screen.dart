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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('asset/image/logo.png', width: 400, height: 300,),
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
