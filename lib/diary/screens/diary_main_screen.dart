import 'package:dearlog/diary/models/diary_entry.dart';
import 'package:dearlog/diary/providers/diary_providers.dart';
import 'package:dearlog/diary/screens/diary_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/shared_widgets/chart/emotion_chart_widget.dart';
import '../../user/providers/user_fetch_providers.dart';

class DiaryMainScreen extends ConsumerWidget {
  const DiaryMainScreen({super.key});

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
                const SizedBox(height: 20),
                InkWell(
                  onTap: () {
                    final diary = ref.read(generatedDiaryProvider);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => DiaryDetailScreen(
                              diary:
                                  diary ??
                                  DiaryEntry(
                                    id: 'no Entry',
                                    date: DateTime(1000, 1, 1),
                                    title: 'no Entry',
                                    content: 'no Entry',
                                    emotion: 'no Entry',
                                    imageUrls: ['https://images.unsplash.com/photo-1506744038136-46273834b3fb'],
                                  ),
                            ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          // 그림자 색상 (파스텔톤 그레이 느낌)
                          blurRadius: 10,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '내 일기 확인하기',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
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
