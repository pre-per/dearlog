import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/mainscreen_index_provider.dart';
import '../../core/shared_widgets/dialog/subscription_dialog.dart';
import '../../core/shared_widgets/tile/promotile.dart';


class AdditionalServiceSection extends StatelessWidget {
  final WidgetRef ref;

  const AdditionalServiceSection({super.key, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 50, bottom: 10),
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
    );
  }
}
