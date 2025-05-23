import 'package:dearlog/widget/divider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/user_fetch_providers.dart';
import '../../widget/emotion_chart_widget.dart';

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
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
                const SizedBox(height: 40),
                Text(
                  '일기장',
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                DividerWidget(),
                EmotionChartWidget(),
                DividerWidget(),
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
