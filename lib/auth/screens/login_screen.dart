import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dearlog/app.dart';

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
    return BaseScaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            Image.asset('asset/image/logo_white.png', width: 300, height: 300),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: GestureDetector(
                onTap: () => _handleGoogleSignIn(context, ref),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    color: Colors.white
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'asset/image/google_icon.png',
                        width: 32,
                      ),
                      const SizedBox(width: 10),
                      const Text('구글로 로그인하기', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16),)
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}