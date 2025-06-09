import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/shared_widgets/chart/emotion_chart_widget.dart';
import '../../core/shared_widgets/elevated_card_container.dart';
import '../../user/providers/user_fetch_providers.dart';

class AnalyticsMainScreen extends ConsumerWidget {
  const AnalyticsMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
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
                  child: _WhoMatchesWithMeWidget(),
                ),

              ],
            ),
          );
        },
        error:
            (err, _) => Center(
              child: Text('사용자 정보를 불러올 수 없습니다\n오류:$err', softWrap: true),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _WhoMatchesWithMeWidget extends StatelessWidget {
  const _WhoMatchesWithMeWidget();

  @override
  Widget build(BuildContext context) {
    return ElevatedCardContainer(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '나와 알맞는 상대는?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '궁금하면 클릭해보세요',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Icon(
                IconsaxPlusBold.heart,
                color: Colors.pinkAccent[100],
                size: 40,
              ),
            ],
          ),
        ),
      ],
    );
  }
}