class Message {
  final String role; // "user" or "assistant"
  final String content;

  Message({
    required this.role,
    required this.content,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'],
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}

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
