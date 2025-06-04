import 'package:dearlog/providers/user/user_fetch_providers.dart';
import 'package:dearlog/screens/chat/chat_home_screen.dart';
import 'package:dearlog/screens/profile/notice_screen.dart';
import 'package:dearlog/widget/divider_widget.dart';
import 'package:dearlog/widget/chart/emotion_chart_widget.dart';
import 'package:dearlog/widget/recent_conversation_widget.dart';
import 'package:dearlog/widget/white_card_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../main.dart';
import '../../models/chart/chart_data.dart';
import '../../providers/mainscreen_index_provider.dart';
import '../../widget/chart/my_bar_chart.dart';
import '../../widget/tile/conversation_summary_tile.dart';
import '../../widget/tile/promotile.dart';
import '../../widget/dialog/subscription_dialog.dart';

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
              onTap: () {},
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
                const SizedBox(height: 10),
                PromoTile(
                  iconEmoji: '📣',
                  title: '디어로그와 통화하고 분석받기',
                  subtitle: ' 오늘의 미션',
                  onTap: () {
                    ref.read(MainIndexProvider.notifier).state = 1;
                  },
                ),
                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  child: Text(
                    '디어로그와 통화하기',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                _callWithDearlogWidget(),

                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  child: WhiteCardContainer(children: [
                    const SizedBox(height: 10),
                    Text('나와 알맞는 상대는?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),),
                    Text('궁금하면 클릭해보세요', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),),
                    const SizedBox(height: 10),
                  ])
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  child: Text(
                    '내 감정 그래프',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                EmotionChartWidget(),

                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  child: Text(
                    '최근 대화 기록',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                RecentConversationWidget(),

                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  child: Text(
                    '부가 기능',
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
                const SizedBox(height: 10),
                PromoTile(
                  iconEmoji: '🥰',
                  title: '내 취향에 맞추어 소개팅하기',
                  subtitle: ' 이건 어때요?',
                  onTap: () {
                    ref.read(MainIndexProvider.notifier).state = 2;
                  },
                ),
                const SizedBox(height: 15),
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

class _callWithDearlogWidget extends ConsumerWidget {
  const _callWithDearlogWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WhiteCardContainer(
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(Icons.call, color: Colors.green[400], size: 40),
              ),
            ),
            const SizedBox(width: 20),
            Text(
              '디어로그님!\n오늘도 통화해볼까요?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 30),
        InkWell(
          onTap: () {
            ref.read(MainIndexProvider.notifier).state = 1;
          },
          child: Container(
            width: double.infinity,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.blueAccent,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1), // 그림자 색상 (파스텔톤 그레이 느낌)
                  blurRadius: 10,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '통화하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
