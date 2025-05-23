import 'package:dearlog/providers/user/user_fetch_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/conversation/conversation.dart';
import '../../models/conversation/message.dart';
import '../../repository/conversation/conversation_repository.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository();
});

final userConversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  if (useDummyData) {
    return [
      Conversation(
        conversationId: 'conv_001',
        timestamp: DateTime.now().subtract(Duration(minutes: 10)),
        analyzed: true,
        messages: [
          Message(role: 'user', content: '오늘 기분이 좀 별로야.'),
          Message(role: 'assistant', content: '무슨 일 있었어? 괜찮아?'),
        ],
      ),
      Conversation(
        conversationId: 'conv_002',
        timestamp: DateTime.now().subtract(Duration(hours: 2)),
        analyzed: false,
        messages: [
          Message(role: 'user', content: '점심 뭐 먹을까 고민 중이야.'),
          Message(role: 'assistant', content: '한식 어때? 따뜻한 국물 있는 걸로!'),
        ],
      ),
    ];
  }

  final userId = ref.watch(userIdProvider);
  if (userId == null) return [];
  final repo = ref.read(conversationRepositoryProvider);
  return repo.fetchConversations(userId);
});
