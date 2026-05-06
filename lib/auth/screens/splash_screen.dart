import 'dart:async';
import 'dart:io';
import 'package:dearlog/app.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

      // 3. user가 존재하면 프로필 완성도 체크 → 미완성이면 온보딩 마저 진행.
      if (user != null) {
        saveUserPushToken(user.id);

        if (!user.profile.isComplete) {
          // 닉네임/성별/나잇대/관심사 중 하나라도 비어있으면 강제 입력.
          // 기존 draft에 일부 정보가 남아 있으면 거기서 이어가도록 미리 채워놓음.
          ref.read(onboardingDraftProvider.notifier).state = OnboardingDraft(
            nickname: user.profile.nickname,
            gender: user.profile.gender,
            ageGroup: user.profile.ageGroup,
            interests: user.profile.interests,
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const OnboardingNameScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
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
    return BaseScaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('asset/image/logo_white.png', width: 300, height: 300),
            SizedBox(height: 50),
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 50),
            Text("앱을 시작하는 중입니다...", style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

Future<void> saveUserPushToken(String userId) async {
  final messaging = FirebaseMessaging.instance;

  // iOS는 APNS 토큰이 준비된 후에만 FCM 토큰을 발급받을 수 있음
  // APNS 토큰이 준비될 때까지 최대 5회 재시도
  if (Platform.isIOS) {
    String? apnsToken;
    for (int i = 0; i < 5; i++) {
      apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null) break;
      await Future.delayed(const Duration(seconds: 2));
    }
    if (apnsToken == null) return; // 시뮬레이터 등 APNS 미지원 환경에서는 정상적으로 skip
  }

  final fcmToken = await messaging.getToken();
  if (fcmToken != null) {
    debugPrint('🔑 FCM 토큰: $fcmToken');
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'fcmToken': fcmToken,
    }, SetOptions(merge: true));
  }

  messaging.onTokenRefresh.listen((token) {
    debugPrint('🔄 FCM 토큰 갱신됨: $token');
    FirebaseFirestore.instance.collection('users').doc(userId).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  });
}
