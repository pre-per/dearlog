import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../repository/conversation/live_conversation_repository.dart';

final liveConversationRepositoryProvider = Provider<LiveConversationRepository>((ref) {
  return LiveConversationRepository();
});

final liveConversationStreamProvider = StreamProvider<Message>((ref) {
  final repo = ref.read(liveConversationRepositoryProvider);
  return repo.streamLiveConversation();
});
