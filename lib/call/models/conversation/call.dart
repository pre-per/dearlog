import 'message.dart';

class Call {
  final String callId; // 고유 식별자
  final DateTime timestamp; // 통화 종료 시간
  final Duration duration; // 통화 지속 시간
  final List<Message> messages; // 메시지 목록

  Call({
    required this.callId,
    required this.timestamp,
    required this.duration,
    required this.messages,
  });

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      callId: json['callId'],
      timestamp: DateTime.parse(json['timestamp']),
      duration: Duration(seconds: json['duration']),
      messages: (json['messages'] as List)
          .map((m) => Message.fromJson(m))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'timestamp': timestamp.toIso8601String(),
      'duration': duration.inSeconds,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}
