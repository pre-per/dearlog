import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/di/providers.dart';
import '../../call/models/conversation/message.dart';
import '../../diary/models/diary_entry.dart';
import '../../user/providers/user_fetch_providers.dart';

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

  /// 사용자가 STT 오인식 결과를 직접 수정한 경우 호출.
  /// AI 재응답은 일으키지 않고, 일기 저장 시 잘못된 단어가 남지 않도록 텍스트만 갈아끼운다.
  void updateUserMessage(int index, String newContent) {
    if (index < 0 || index >= state.length) return;
    if (state[index].role != 'user') return;
    final updated = List<Message>.from(state);
    updated[index] = Message(role: 'user', content: newContent);
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
      final profile = ref.read(userProfileProvider);
      final userId = ref.read(userIdProvider);

      // 최근 일기 3개 — 친구처럼 익숙한 맥락을 알도록. 실패해도 응답 자체는 진행.
      List<DiaryEntry> recent = const [];
      if (userId != null) {
        try {
          recent = await ref
              .read(diaryRepositoryProvider)
              .fetchRecentDiaries(userId, limit: 3);
        } catch (_) {
          // ignore — 컨텍스트 없이도 통화는 계속.
        }
      }

      final response = await service.getChatResponse(
        state,
        profile: profile,
        recentDiaries: recent,
      );
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
