import 'package:dearlog/core/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dearlog/main.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../providers/google_auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  Future<void> _handleGoogleSignIn(BuildContext context, WidgetRef ref) async {
    try {
      // 로그인 시도
      await ref.read(googleAuthProvider.notifier).login();
      final firebaseUser = ref.read(googleAuthProvider);

      if (firebaseUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("로그인에 실패했습니다.")),
        );
        return;
      }

      final userRepo = ref.read(userRepositoryProvider);
      final userId = firebaseUser.uid;
      final email = firebaseUser.email ?? '';

      ref.read(userIdProvider.notifier).state = userId;

      // 유저 데이터 존재 여부 확인
      final existingUser = await userRepo.fetchUser(userId);

      if (existingUser == null) {
        // 신규 유저 → Firestore에 초기 데이터 생성
        await userRepo.initializeNewUser(
          userId: userId,
          email: email,
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
              (route) => false,
        );
      } else {
        // 메인화면 이동
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
              (route) => false,
        );
      }
    } catch (e) {
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
