import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../call/models/conversation/message.dart';
import '../../core/services/openai_service.dart';

final messageProvider = StateNotifierProvider<MessageNotifier, List<Message>>(
      (ref) => MessageNotifier(),
);

class MessageNotifier extends StateNotifier<List<Message>> {
  MessageNotifier()
      : super([
    Message(role: 'assistant', content: '여보세요? 오늘 하루는 어땠어?'),
  ]);

  void addUserMessage(String text) {
    final userMsg = Message(role: 'user', content: text);
    state = [...state, userMsg, Message(role: 'assistant', content: '__loading__')];
  }

  Future<void> getAssistantResponse() async {
    try {
      final service = OpenAIService();
      final response = await service.getChatResponse(state);
      state = [
        for (final m in state)
          if (!(m.role == 'assistant' && m.content == '__loading__')) m,
        response.message,
      ];
    } catch (e) {
      state = [
        for (final m in state)
          if (!(m.role == 'assistant' && m.content == '__loading__')) m,
        Message(role: 'assistant', content: '죄송해요. 지금은 응답할 수 없어요. 에러: $e'),
      ];
    }
  }
}
