import 'package:dearlog/core/screens/login_screen.dart';
import 'package:dearlog/home/widgets/call_starter_card.dart';
import 'package:dearlog/home/widgets/diary_preview_scroller.dart';
import 'package:dearlog/user/providers/user_fetch_providers.dart';
import 'package:dearlog/settings/screens/notice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/shared_widgets/chart/emotion_chart_widget.dart';
import '../../core/shared_widgets/dialog/subscription_dialog.dart';
import '../../core/shared_widgets/tile/promotile.dart';
import '../../main.dart';
import '../../core/providers/mainscreen_index_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
              (Route<dynamic> route) => false,
            );
          },
          child: Image.asset('asset/image/logo.png', width: 120, height: 120),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => NoticeScreen()));
            },
            icon: Icon(
              IconsaxPlusBold.notification,
              color: Colors.grey[400],
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
        ],
      ),

      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return GestureDetector(
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (route) => false,
                );
              },
              child: Center(
                child: Text(
                  '로그인 해주세요',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 25, bottom: 15),
                  child: Text(
                    '오늘 하루 이야기해볼까요?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                CallStarterCard(),

                Padding(
                  padding: const EdgeInsets.only(top: 50, bottom: 10),
                  child: Text(
                    '그림일기로 돌아보는 하루',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                  ),
                ),
                DiaryPreviewScroller(entries: user.diaries),

                Padding(
                  padding: const EdgeInsets.only(top: 50, bottom: 10),
                  child: Text(
                    '최근 감정 그래프',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                EmotionChartWidget(),

                Padding(
                  padding: const EdgeInsets.only(top: 50, bottom: 10),
                  child: Text(
                    '부가 서비스',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                PromoTile(
                  iconEmoji: '🌟',
                  title: '디어로그 프로모션 가입하기',
                  subtitle: ' 통화할 때마다 뜨는 광고가 싫다면',
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder:
                          (_) => SubscriptionDialog(
                            onConfirm: (selectedPlan) {
                              print('선택한 플랜: $selectedPlan');
                              // 결제 로직 호출 등
                            },
                          ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                PromoTile(
                  iconEmoji: '🥰',
                  title: '내 취향에 맞추어 소개팅하기',
                  subtitle: ' 이건 어때요?',
                  onTap: () {
                    ref.read(MainIndexProvider.notifier).state = 2;
                  },
                ),
                const SizedBox(height: 12),
                PromoTile(
                  iconEmoji: '📣',
                  title: '디어로그와 통화하고 분석받기',
                  subtitle: ' 오늘의 미션',
                  onTap: () {
                    ref.read(MainIndexProvider.notifier).state = 1;
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
        error: (err, _) => Center(child: Text('유저 데이터를 불러오지 못했습니다.\n오류:$err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
