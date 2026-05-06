import 'package:dearlog/app.dart';

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

      saveUserPushToken(userId);

      if (existingUser == null) {
        // 신규 유저 → Firestore에 초기 데이터 생성 + 약관 동의부터.
        await userRepo.initializeNewUser(
          userId: userId,
          email: email,
        );

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingAgreementScreen()),
        );
      } else if (!existingUser.profile.isComplete) {
        // 기존 유저인데 프로필 정보 일부가 비어있으면 마저 입력하게 한다.
        // 이전에 입력한 일부 값은 draft에 미리 채워서 이어 진행 가능.
        ref.read(onboardingDraftProvider.notifier).state = OnboardingDraft(
          nickname: existingUser.profile.nickname,
          gender: existingUser.profile.gender,
          ageGroup: existingUser.profile.ageGroup,
          interests: existingUser.profile.interests,
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingNameScreen()),
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