import 'package:dearlog/providers/user_fetch_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../repository/conversation_repository.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository();
});

final userConversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return [];
  final repo = ref.read(conversationRepositoryProvider);
  return repo.fetchConversations(userId);
});
