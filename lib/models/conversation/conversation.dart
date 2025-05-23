import 'message.dart';

class Conversation {
  final String conversationId;
  final DateTime timestamp;
  final List<Message> messages;
  final bool analyzed;

  Conversation({
    required this.conversationId,
    required this.timestamp,
    required this.messages,
    required this.analyzed,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      conversationId: json['conversationId'],
      timestamp: DateTime.parse(json['timestamp']),
      messages: (json['messages'] as List)
          .map((m) => Message.fromJson(m))
          .toList(),
      analyzed: json['analyzed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'timestamp': timestamp.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'analyzed': analyzed,
    };
  }
}
