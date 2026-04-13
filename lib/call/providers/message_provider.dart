import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/di/providers.dart';
import '../../call/models/conversation/message.dart';

final messageProvider = StateNotifierProvider<MessageNotifier, List<Message>>(
      (ref) => MessageNotifier(ref),
);

class MessageNotifier extends StateNotifier<List<Message>> {
  final Ref ref;

  MessageNotifier(this.ref)
      : super([Message(role: 'assistant', content: '여보세요? 오늘 하루는 어땠어?')]);

  void addUserMessage(String text) {
    state = [...state, Message(role: 'user', content: text), Message(role: 'assistant', content: '__loading__')];
  }

  /// 스트리밍 중 마지막 assistant 메시지 내용을 실시간 업데이트
  void updateStreaming(String fullContent) {
    final idx = state.lastIndexWhere((m) => m.role == 'assistant');
    if (idx == -1) return;
    final updated = List<Message>.from(state);
    updated[idx] = Message(role: 'assistant', content: fullContent);
    state = updated;
  }

  void clear() {
    state = [Message(role: 'assistant', content: '여보세요? 오늘 하루는 어땠어?')];
  }

  void restore(List<Message> messages) {
    state = messages;
  }

  Future<void> getAssistantResponse() async {
    try {
      final service = ref.read(openAIServiceProvider); // ⬅️ di 주입 사용
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
