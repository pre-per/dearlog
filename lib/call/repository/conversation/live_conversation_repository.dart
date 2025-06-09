import '../../models/conversation/conversation.dart';
import '../../models/conversation/message.dart';

class LiveConversationRepository {
  /// 실제 통신 대신 더미 데이터 스트림 반환
  Stream<Message> streamLiveConversation() async* {
    await Future.delayed(const Duration(seconds: 1));
    yield Message(role: 'assistant', content: '안녕하세요! 무엇을 도와드릴까요?');
  }

/// 여기에 실제 API 연결 (WebSocket, SSE, gRPC 등) 구현 예정
}
