import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dearlog/app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// `users/{uid}.agreedTermsAt` 필드 존재 여부로 약관 단계 통과 여부를 판단.
/// 네트워크 실패 시 보수적으로 true (이미 동의한 사용자가 약관을 다시 보지 않게).
/// splash_screen 의 동일 로직과 의도적으로 중복 — 두 진입점에서 같은 분기 필요.
Future<bool> _hasAgreedTerms(String userId) async {
  try {
    final snap =
        await FirebaseFirestore.instance.doc('users/$userId').get();
    if (!snap.exists) return false;
    return snap.data()?['agreedTermsAt'] != null;
  } catch (_) {
    return true;
  }
}

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  Future<void> _handleGoogleSignIn(BuildContext context, WidgetRef ref) async {
    try {
      // 로그인 시도
      await ref.read(googleAuthProvider.notifier).login();
      final firebaseUser = ref.read(googleAuthProvider);
      if (!context.mounted) return;
      await _routeAfterLogin(context, ref, firebaseUser);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("로그인 중 오류 발생: $e")),
      );
    }
  }

  /// 애플 로그인 — App Store 심사 가이드라인 4.8 (서드파티 로그인 제공 시
  /// Sign in with Apple 필수) 대응. 로그인 이후 분기는 구글과 완전히 동일.
  Future<void> _handleAppleSignIn(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(appleAuthProvider.notifier).login();
      final firebaseUser = ref.read(appleAuthProvider);
      if (!context.mounted) return;
      await _routeAfterLogin(context, ref, firebaseUser);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      // 같은 이메일이 이미 다른 제공자로 가입돼 있는 경우 — 기존 계정의 데이터가
      // 분리되지 않게 원래 방식으로 로그인하도록 안내한다.
      if (e.code == 'account-exists-with-different-credential') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 같은 이메일로 가입된 계정이 있어요. 구글 로그인으로 시도해 주세요.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("로그인 중 오류 발생: ${e.message ?? e.code}")),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("로그인 중 오류 발생: $e")),
      );
    }
  }

  /// 로그인 성공 후 공통 분기 — 어떤 제공자로 로그인했든 신규/기존 유저 처리와
  /// 온보딩 진입 조건은 동일해야 한다.
  Future<void> _routeAfterLogin(
    BuildContext context,
    WidgetRef ref,
    User? firebaseUser,
  ) async {
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
    // ignore: unawaited_futures
    AnalyticsService.setUserId(userId);

    // 유저 데이터 존재 여부 확인
    final existingUser = await userRepo.fetchUser(userId);

    // GA4 segmentation 용 인구통계 user property — 기존 유저면 기존 값,
    // 신규 유저는 빈 값 (다음 setUserProperties 호출이 onboarding 완료 후
    // 새 값으로 덮어씀).
    // ignore: unawaited_futures
    AnalyticsService.setUserProperties(
      gender: existingUser?.profile.gender,
      ageGroup: existingUser?.profile.ageGroup,
    );

    saveUserPushToken(userId);

    if (existingUser == null) {
      // 신규 유저 → Firestore에 초기 데이터 생성 + 약관 동의부터.
      await userRepo.initializeNewUser(
        userId: userId,
        email: email,
      );

      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingAgreementScreen()),
        (route) => false,
      );
    } else if (!existingUser.profile.isComplete) {
      // 기존 유저인데 프로필 정보 일부가 비어있으면 마저 입력하게 한다.
      // 단, 약관 동의를 아직 안 한 사용자(약관 화면에서 뒤로가기로 빠져나온 케이스)는
      // 약관 단계부터 다시 시작해야 한다.
      final agreed = await _hasAgreedTerms(userId);
      if (!context.mounted) return;
      ref.read(onboardingDraftProvider.notifier).state = OnboardingDraft(
        nickname: existingUser.profile.nickname,
        gender: existingUser.profile.gender,
        ageGroup: existingUser.profile.ageGroup,
        interests: existingUser.profile.interests,
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => agreed
              ? const OnboardingNameScreen()
              : const OnboardingAgreementScreen(),
        ),
        (route) => false,
      );
    } else {
      // 메인화면 이동
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 애플 로그인은 iOS 에서만 노출 — 심사 요건도 iOS 에만 적용되고,
    // 안드로이드는 별도 웹 인증(Service ID) 설정 없이는 동작하지 않는다.
    final showAppleLogin = !kIsWeb && Platform.isIOS;

    return BaseScaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            Image.asset('asset/image/logo_white.png', width: 300, height: 300),
            const Spacer(),
            if (showAppleLogin) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _LoginButton(
                  onTap: () => _handleAppleSignIn(context, ref),
                  icon: const Icon(Icons.apple, color: Colors.black, size: 32),
                  label: 'Apple로 로그인하기',
                ),
              ),
              const SizedBox(height: 14),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _LoginButton(
                onTap: () => _handleGoogleSignIn(context, ref),
                icon: Image.asset('asset/image/google_icon.png', width: 32),
                label: '구글로 로그인하기',
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// 로그인 버튼 공통 모양 — 흰 배경 알약형.
/// (애플 HIG 기준 어두운 배경 위에서는 흰색 Sign in with Apple 버튼을 권장하고,
/// 다른 로그인 버튼과 같은 크기/스타일로 노출해야 한다)
class _LoginButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget icon;
  final String label;

  const _LoginButton({
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
