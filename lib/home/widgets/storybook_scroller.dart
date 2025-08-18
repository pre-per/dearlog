import 'package:dearlog/core/shared_widgets/storybook_widget.dart';
import 'package:flutter/material.dart';
import '../../diary/models/diary_entry.dart';

class StorybookScroller extends StatelessWidget {
  final List<DiaryEntry> entries;

  const StorybookScroller({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => StorybookWidget(entry: entries[index])
        ,
      ),
    );
  }
}
