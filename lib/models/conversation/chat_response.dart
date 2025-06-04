import 'message.dart';

class ChatResponse {
  final Message message;
  final int totalTokens;

  ChatResponse({required this.message, required this.totalTokens});
}
