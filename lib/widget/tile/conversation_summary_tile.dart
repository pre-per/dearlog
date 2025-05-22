import 'package:flutter/material.dart';

class ConversationSummaryTile extends StatelessWidget {
  final DateTime date;
  final String emoji;
  final String summary;
  final VoidCallback? onTap;

  const ConversationSummaryTile({
    super.key,
    required this.date,
    required this.emoji,
    required this.summary,
    this.onTap,
  });

  String get formattedDate =>
      '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade100,
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
      title: Text(
        summary,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        formattedDate,
        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}
