import 'package:iconsax_plus/iconsax_plus.dart';
import 'app.dart';
import 'community/screens/community_main_screen.dart';
import 'community/screens/post_detail_screen.dart';
import 'community/widgets/rank_celebration_overlay.dart';
import 'fortune/services/daily_fortune_notification.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  // main() 의 await 가 길수록 Flutter 첫 프레임 전까지 검은 화면이 길게 보인다.
  // 필수 init 만 여기서 처리하고 나머지는 SplashScreen 에서 진행률을 보여주며 처리.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('ko_KR', null);
  // CBT 지표 — app_open. Firebase 가 자동 수집하지만 콜드 스타트 누락 가능성 차단.
  // fire-and-forget — analytics 실패가 앱 진입을 막으면 안 됨.
  // ignore: unawaited_futures
  AnalyticsService.logAppOpen();
  _wireRemoteMessageHandlers(); // fire-and-forget — main 흐름을 막지 않는다
  runApp(ProviderScope(child: MyApp()));
}

/// FCM 푸시(원격 알림) 탭 → 앱 내 라우팅 연결.
///
/// `data.payload` 가 있는 메시지가 들어오면 [NotificationCenter] 에 흘려보내고,
/// 이후 `MainScreen._handlePendingNotificationPayload` 가 일기/게시물 등 화면으로
/// 디스패치한다. 로컬 알림과 FCM 푸시 양쪽 모두 동일 페이로드 규칙을 공유한다.
///
/// iOS 시뮬레이터처럼 APNS 토큰이 발급될 수 없는 환경에서는
/// `getInitialMessage()` 가 영원히 pending 상태가 될 수 있어, main 진입을 막지
/// 않도록 fire-and-forget + 짧은 timeout 으로 보호한다.
void _wireRemoteMessageHandlers() {
  // 백그라운드/포그라운드에서 알림 탭으로 앱이 열릴 때 — 즉시 등록 (sync).
  FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    final p = msg.data['payload'];
    if (p is String && p.isNotEmpty) NotificationCenter.post(p);
  });

  // 종료 상태(콜드 스타트)에서 알림 탭으로 앱이 처음 열린 경우 — 비동기 처리.
  () async {
    try {
      final initial = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 3));
      if (initial == null) return;
      final p = initial.data['payload'];
      if (p is String && p.isNotEmpty) NotificationCenter.post(p);
    } catch (e) {
      debugPrint('[NOTI] getInitialMessage 스킵 (timeout/실패): $e');
    }
  }();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: notificationNavigatorKey,
      // 화면 전환마다 screen_view 자동 기록 — IndexedStack 탭 전환은 별도로 명시 호출.
      navigatorObservers: [AnalyticsService.observer],
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          iconTheme: const IconThemeData(color: Colors.white),
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        scaffoldBackgroundColor: Colors.transparent,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
        ),
        bottomAppBarTheme: BottomAppBarThemeData(color: Colors.grey[50]),
        // ✅ 스낵바: 어두운 배경 + 명시적 흰색 텍스트로 통일.
        //    (Material 3 default는 dark theme에서 반전 색상을 써서, 우리가 backgroundColor만
        //     어둡게 덮어쓰면 글씨가 어두운 색이 되어 안 보이는 문제가 있었음.)
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1E1E2E),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
            fontFamily: 'GowunBatang',
            fontWeight: FontWeight.w500,
          ),
          behavior: SnackBarBehavior.floating,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        fontFamily: 'GowunBatang',
        brightness: Brightness.dark,
      ),
      home: SplashScreen(),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  final String? snackMessage;

  const MainScreen({
    super.key,
    this.snackMessage,
  });

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _screens = [
    HomeScreen(),
    DiaryMainScreen(),
    AnalysisScreen(),
    CommunityMainScreen(),
    SettingMainScreen(),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = widget.snackMessage;
      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.grey[600],
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 콜드 스타트 시 큐잉된 알림 페이로드 처리
      _handlePendingNotificationPayload();

      // 오늘의 운세 일일 알림 — 사용자가 설정에서 켜둔 경우 매일 같은 시간에
      // 재예약. cancel 후 새로 등록하므로 시간 변경/끄기도 자연스럽게 반영.
      // fire-and-forget — 실패해도 다음 진입에서 다시 시도.
      // ignore: unawaited_futures
      DailyFortuneNotificationScheduler.refresh().catchError((e) {
        debugPrint('[NOTI] daily fortune refresh 실패: $e');
      });
    });

    // 포그라운드/백그라운드 탭 페이로드 구독
    NotificationCenter.pendingPayload.addListener(_handlePendingNotificationPayload);
  }

  @override
  void dispose() {
    NotificationCenter.pendingPayload.removeListener(_handlePendingNotificationPayload);
    super.dispose();
  }

  Future<void> _handlePendingNotificationPayload() async {
    final payload = NotificationCenter.consume();
    if (payload == null) return;
    debugPrint('[알림] dispatch payload=$payload');

    if (payload == NotificationPayload.dailyReminder) {
      // 일일 리마인더 → 일기장 탭으로 전환
      ref.read(MainIndexProvider.notifier).state = 1;
      return;
    }

    if (payload == NotificationPayload.dailyFortune) {
      // 오늘의 운세 알림 → 홈 탭으로. 떠다니는 유리병이 사용자 시선에 들어가도록.
      ref.read(MainIndexProvider.notifier).state = 0;
      return;
    }

    final commentPostId = NotificationPayload.extractCommentPostId(payload);
    if (commentPostId != null) {
      // 댓글 알림 → 게시물 상세로 이동
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(postId: commentPostId),
        ),
      );
      return;
    }

    final diaryId = NotificationPayload.extractDiaryId(payload);
    if (diaryId != null) {
      final userId = ref.read(userIdProvider);
      if (userId == null) return;
      try {
        final diary = await ref
            .read(diaryRepositoryProvider)
            .fetchDiaryById(userId, diaryId);
        if (diary == null) {
          debugPrint('[알림] diaryId=$diaryId 일기 없음 — dispatch 스킵');
          return;
        }
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DiaryDetailScreen(diary: diary)),
        );
      } catch (e) {
        debugPrint('[알림] dispatch 실패: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int currentIndex = ref.watch(MainIndexProvider);
    // IndexedStack 으로 탭별 state 를 유지 — 캘린더 focused-month, 검색어, 스크롤 위치
    // 등이 탭 전환 시 사라지지 않게.
    return BaseScaffold(
      body: RankCelebrationHost(
        child: Stack(
          children: [
            IndexedStack(index: currentIndex, children: _screens),
            // 글로벌 통화 배너 — 어느 탭에서도 같은 인스턴스가 떠 있고, 표시 중에는
            // CallStartIconbutton 이 비활성화되어 중복으로 쌓이지 않는다.
            const _GlobalIncomingCallOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: GlassBottomNav(
        currentIndex: currentIndex,
        onTap: (index) {
          // CBT 지표 — 분석 탭 진입은 AI 산출물(감정/월간 인사이트) 조회로 카운트.
          // IndexedStack 이라 화면 initState 가 첫 진입 1회만 트리거되므로
          // 매번 잡으려면 탭 onTap 에서 직접 발사해야 한다.
          if (index == 2 && currentIndex != 2) {
            // ignore: unawaited_futures
            AnalyticsService.logReportViewed(source: 'analysis');
          }
          setState(() => ref.read(MainIndexProvider.notifier).state = index);
        },
        items: const [
          GlassNavItem(svgPath: 'asset/icons/navigation/planet.svg', label: '홈'),
          GlassNavItem(svgPath: 'asset/icons/navigation/moon_stars.svg', label: '일기장'),
          GlassNavItem(svgPath: 'asset/icons/navigation/analytics.svg', label: '분석'),
          GlassNavItem(icon: IconsaxPlusBold.profile_2user, label: '커뮤니티'),
          GlassNavItem(svgPath: 'asset/icons/navigation/user.svg', label: '마이'),
        ],
      ),
    );
  }
}

// _requestNotificationPermission 은 SplashScreen.\_requestFcmPermission 으로 이동.
// main() 의 await 를 줄여 OS 검은 화면을 짧게 만들기 위함.

/// MainScreen 의 IndexedStack 위에 항상 마운트되는 글로벌 통화 배너.
///
/// [incomingCallVisibleProvider] 가 true 가 되면 [IncomingCallBanner] 가
/// 화면 상단에서 슬라이드 인. 어느 탭에 있든 동일하게 떠 있고, 수락/거부 결정
/// 시까지 모든 [CallStartIconbutton] 이 비활성화된다.
class _GlobalIncomingCallOverlay extends ConsumerWidget {
  const _GlobalIncomingCallOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(incomingCallVisibleProvider);
    if (!visible) return const SizedBox.shrink();

    void dismiss() {
      ref.read(incomingCallVisibleProvider.notifier).state = false;
    }

    return IncomingCallBanner(
      callerName: '디어로그',
      callerSubtitle: '휴대전화',
      onAccept: () {
        dismiss();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AiChatScreen()),
        );
      },
      onDecline: () {
        dismiss();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '시간 날 때 다시 걸어주세요! :)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.grey[600],
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}
