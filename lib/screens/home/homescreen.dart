import 'package:dearlog/providers/user_fetch_providers.dart';
import 'package:dearlog/screens/chat/chat_home_screen.dart';
import 'package:dearlog/screens/home/notification_screen.dart';
import 'package:dearlog/widget/divider_widget.dart';
import 'package:dearlog/widget/emotion_chart_widget.dart';
import 'package:dearlog/widget/recent_conversation_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../main.dart';
import '../../models/emotiondata.dart';
import '../../providers/mainscreen_index_provider.dart';
import '../../widget/emotion_chart.dart';
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
    final userProfileAsync = ref.watch(userProfileProvider);

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
              ).push(MaterialPageRoute(builder: (_) => NotificationScreen()));
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

      body: userProfileAsync.when(
        data: (userProfile) {
          if (userProfile == null) {
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
                const SizedBox(height: 20),
                PromoTile(
                  iconEmoji: '📣',
                  title: '디어로그와 통화하고 분석받기',
                  subtitle: ' 오늘의 미션',
                  onTap: () {
                    ref.read(MainIndexProvider.notifier).state = 1;
                  },
                ),
                const SizedBox(height: 25),

                EmotionChartWidget(),
                DividerWidget(),

                RecentConversationWidget(),
                DividerWidget(),

                Text(
                  '  부가 기능',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 15),
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
                const SizedBox(height: 15),
                PromoTile(
                  iconEmoji: '🥰',
                  title: '내 취향에 맞추어 소개팅하기',
                  subtitle: ' 이건 어때요?',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChatHomeScreen()),
                    );
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
