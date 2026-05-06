import 'dart:async';
import 'dart:io';
import 'package:dearlog/app.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// 0.0 ~ 1.0 진행률. 단계별로 step up.
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _step(0.10, () async {
      // RemoteConfig — OpenAI API 키 fetch. 실패해도 retry 가 살아 있어 진행은 OK.
      await RemoteConfigService().initialize();
    });

    await _step(0.30, () async {
      // 알림 권한 (iOS 첫 실행 시 prompt — 그동안 진행률 멈춤은 자연스럽다)
      await _requestFcmPermission();
    });

    await _step(0.50, () async {
      // 로컬 알림 채널/타임존 init.
      await LocalNotificationService.instance.init();
    });

    await _step(0.70, () async {
      // 인증 + 사용자 fetch + 분기 결정 직전까지.
    });

    await _routeAfterAuth();
  }

  /// 다음 단계 진행률로 부드럽게 올린 뒤 작업 실행.
  Future<void> _step(double target, Future<void> Function() work) async {
    if (!mounted) return;
    setState(() => _progress = target);
    await work();
  }

  Future<void> _requestFcmPermission() async {
    final messaging = FirebaseMessaging.instance;
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[NOTI] FCM 권한 상태: ${settings.authorizationStatus}');
      if (kDebugMode) {
        final token = await messaging.getToken();
        debugPrint(
            '[NOTI] FCM token=${token == null ? "null" : "${token.substring(0, 16)}..."}');
      }
    } catch (e, st) {
      debugPrint('[NOTI] ❌ FCM 권한 요청 실패: $e');
      debugPrint('[NOTI] stack: $st');
    }
  }

  Future<void> _routeAfterAuth() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await _finishProgressAndGo(const LoginScreen());
      return;
    }

    ref.read(userIdProvider.notifier).state = currentUser.uid;

    final user = await ref.read(userProvider.future);
    if (user == null) {
      await _finishProgressAndGo(const LoginScreen());
      return;
    }

    saveUserPushToken(user.id);

    if (!user.profile.isComplete) {
      final agreed = await _hasAgreedTerms(user.id);
      if (!mounted) return;
      ref.read(onboardingDraftProvider.notifier).state = OnboardingDraft(
        nickname: user.profile.nickname,
        gender: user.profile.gender,
        ageGroup: user.profile.ageGroup,
        interests: user.profile.interests,
      );
      await _finishProgressAndGo(
        agreed
            ? const OnboardingNameScreen()
            : const OnboardingAgreementScreen(),
      );
    } else {
      await _finishProgressAndGo(const MainScreen());
    }
  }

  Future<void> _finishProgressAndGo(Widget destination) async {
    if (!mounted) return;
    setState(() => _progress = 1.0);
    // 진행 바가 100% 까지 부드럽게 차오르는 모습을 잠깐 보여준 뒤 전환.
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Image.asset(
                'asset/image/logo_white.png',
                width: 300,
                height: 300,
              ),
            ),
            Positioned(
              left: 32,
              right: 32,
              bottom: 64,
              child: Column(
                children: [
                  _GoldProgressBar(progress: _progress),
                  const SizedBox(height: 14),
                  Text(
                    '앱을 시작하는 중입니다...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'GowunBatang',
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 화면 하단에 깔리는 골드 진행 바. 머티리얼 LinearProgressIndicator 대신
/// Container 기반으로 직접 그림 — 글래스 톤과 어울리게 그라데이션 + glow.
class _GoldProgressBar extends StatelessWidget {
  final double progress;
  const _GoldProgressBar({required this.progress});

  static const _gold = Color(0xFFFFD700);
  static const _goldDeep = Color(0xFFFFB347);

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Container(
      height: 5,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: clamped),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [_goldDeep, _gold],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withOpacity(0.55),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// user doc 의 `agreedTermsAt` 필드 존재 여부로 약관 동의 통과 여부 판정.
/// 네트워크 실패 시 보수적으로 true 반환 (이미 동의한 사용자가 재차 동의화면을
/// 보지 않게 — 미동의 상태를 잘못 통과시키는 것보다 동의 후 재진입을 막는 게 덜 위험).
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
