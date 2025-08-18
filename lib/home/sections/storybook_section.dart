import 'package:flutter/material.dart';

import '../../diary/models/diary_entry.dart';
import '../widgets/storybook_scroller.dart';

class StorybookSection extends StatelessWidget {
  final List<DiaryEntry> diaries;

  const StorybookSection({
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
            '스토리북',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
        ),
        StorybookScroller(entries: diaries),
      ],
    );
  }
}