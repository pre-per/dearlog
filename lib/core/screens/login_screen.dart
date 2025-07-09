import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dearlog/main.dart';
import '../providers/google_auth_provider.dart'; // 리버팟 provider 위치에 맞게 수정하세요

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  void _handleGoogleSignIn(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(googleAuthProvider.notifier).login();

      final user = ref.read(googleAuthProvider);
      if (user != null) {
        // 로그인 성공 → 메인 화면 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        // 로그인 실패 처리
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("로그인에 실패했습니다.")),
        );
      }
    } catch (e) {
      // 예외 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("로그인 중 오류 발생: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            Image.asset('asset/image/logo.png', width: 400, height: 300),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton.icon(
                icon: Image.asset(
                  'asset/image/google_icon.png',
                  width: 24,
                  height: 24,
                ),
                label: const Text("Google 계정으로 계속하기"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _handleGoogleSignIn(context, ref),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
