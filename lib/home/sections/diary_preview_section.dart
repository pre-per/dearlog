import 'package:flutter/material.dart';

import '../../diary/models/diary_entry.dart';
import '../widgets/diary_preview_scroller.dart';

class DiaryPreviewSection extends StatelessWidget {
  final List<DiaryEntry> diaries;

  const DiaryPreviewSection({
    super.key,
    required this.diaries,
  });

  @override
  Widget build(BuildContext context) {
    if (diaries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 50, bottom: 10),
          child: Text(
            '그림일기로 돌아보는 하루',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
        ),
        DiaryPreviewScroller(entries: diaries),
      ],
    );
  }
}