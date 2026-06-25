import 'package:flutter/material.dart';

import '../../analysis/widget/keyword_color_palette.dart';
import '../providers/planet_providers.dart';

/// 최근 감정 요약 한 줄 — '최근 감정  평온 42% · 설렘 28% · 불안 18%'.
/// 카드/상세에서 공유한다.
class PlanetEmotionSummary extends StatelessWidget {
  final List<EmotionSlice> emotions;

  /// 가운데 정렬(상세)인지 좌측 정렬(카드)인지.
  final bool center;
  final bool showLeadingLabel;

  const PlanetEmotionSummary({
    super.key,
    required this.emotions,
    this.center = false,
    this.showLeadingLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    if (emotions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showLeadingLabel)
          Text(
            '최근 감정',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        for (final e in emotions)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: keywordGlowColor(e.label),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${e.label} ${e.percent}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
