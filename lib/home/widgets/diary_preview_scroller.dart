import 'package:dearlog/diary/screens/diary_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../diary/models/diary_entry.dart';

class DiaryPreviewScroller extends StatelessWidget {
  final List<DiaryEntry> entries;

  const DiaryPreviewScroller({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final imageUrl =
              entry.imageUrls.isNotEmpty
                  ? entry.imageUrls.first
                  : getEmotionIllustration(entry.emotion); // 기본 감정 일러스트

          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DiaryDetailScreen(diary: entry),
                ),
              );
            },
            child: Container(
              width: 130,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: SizedBox(
                      height: 130,
                      width: 130,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(0),
                          bottomRight: Radius.circular(0),
                        ),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              getEmotionIllustration(entry.emotion),
                              scale: 7,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 8.0,
                      left: 10,
                      right: 10,
                    ),
                    child: Text(
                      entry.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 4.0,
                      left: 10,
                      right: 10,
                    ),
                    child: Text(
                      DateFormat('MM/dd').format(entry.date),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 감정 코드에 따른 기본 이미지 asset 경로 반환
  String getEmotionIllustration(String emotion) {
    switch (emotion) {
      case '행복':
        return 'asset/illustrations/happy.png';
      case '슬픔':
        return 'asset/illustrations/sad.png';
      case '분노':
        return 'asset/illustrations/angry.png';
      case '불안':
        return 'asset/illustrations/fear.png';
      default:
        return 'asset/illustrations/neutral.png';
    }
  }
}
