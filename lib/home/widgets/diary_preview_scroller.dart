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
          final imageUrl = entry.imageUrls.isNotEmpty
              ? entry.imageUrls.first
              : getEmotionIllustration(entry.emotion); // 기본 감정 일러스트

          return GestureDetector(
            onTap: () {
              // 상세 페이지 이동 (선택적으로 구현 가능)
            },
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: imageUrl.startsWith('http')
                              ? Image.network(imageUrl, fit: BoxFit.cover)
                              : Image.asset(imageUrl, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.title,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                          fontWeight: FontWeight.w600
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MM/dd').format(entry.date),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
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
      case 'happy':
        return 'assets/illustrations/happy.png';
      case 'sad':
        return 'assets/illustrations/sad.png';
      case 'angry':
        return 'assets/illustrations/angry.png';
      case 'fear':
        return 'assets/illustrations/fear.png';
      default:
        return 'assets/illustrations/neutral.png';
    }
  }
}
