import 'dart:async';
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

      // 3. user가 존재하면 MainScreen, 없으면 LoginScreen
      if (user != null) {
        /* saveUserPushToken(user.id);
        String? _fcmToken = await FirebaseMessaging.instance.getToken();
        print('Token: $_fcmToken'); */

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
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
  await Future.delayed(Duration(seconds: 2));
  final messaging = FirebaseMessaging.instance;

  final fcmToken = await messaging.getToken();
  if (fcmToken != null) {
    print('🔑 FCM 토큰: $fcmToken');
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'fcmToken': fcmToken,
    }, SetOptions(merge: true));
  }
  FirebaseMessaging.instance.onTokenRefresh.listen((token) {
    print("🔄 FCM 토큰 갱신됨: $token");
  });
}
