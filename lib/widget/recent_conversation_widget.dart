import 'package:dearlog/widget/white_card_container.dart';
import 'package:flutter/material.dart';
import 'tile/conversation_summary_tile.dart';

class RecentConversationWidget extends StatelessWidget {
  const RecentConversationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return WhiteCardContainer(
      children: [
        ConversationSummaryTile(
          date: DateTime(2025, 5, 22),
          emoji: '😊',
          summary: '집중이 잘 되었던 하루였어요.',
        ),
        const SizedBox(height: 10),
        ConversationSummaryTile(
          date: DateTime(2025, 5, 21),
          emoji: '😕',
          summary: '관계에서의 고민이 많았던 하루...',
        ),
        const SizedBox(height: 10),
        ConversationSummaryTile(
          date: DateTime(2025, 5, 20),
          emoji: '😴',
          summary: '피곤하고 무기력했지만 기록은 했다.',
        ),
      ],
    );
  }
}
