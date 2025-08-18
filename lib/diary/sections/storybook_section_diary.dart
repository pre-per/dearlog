import 'package:dearlog/core/shared_widgets/storybook_widget.dart';
import 'package:flutter/material.dart';

import '../models/diary_entry.dart';

class StorybookSectionDiary extends StatelessWidget {
  final List<DiaryEntry> entries;

  const StorybookSectionDiary({
    super.key,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final childAspectRatio = 5 / 6; // 예: 가로가 3이면 세로가 4

    return GridView.builder(
      // ✅ 핵심: 부모(ListView) 안에서 높이 계산 가능하도록
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),

      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return StorybookWidget(entry: entry);
      },
    );

  }
}
