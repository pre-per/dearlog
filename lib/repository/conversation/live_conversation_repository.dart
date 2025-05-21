import '../../models/conversation.dart';

class LiveConversationRepository {
  /// 실제 통신 대신 더미 데이터 스트림 반환
  Stream<Message> streamLiveConversation() async* {
    await Future.delayed(const Duration(seconds: 1));
    yield Message(role: 'assistant', content: '안녕하세요! 무엇을 도와드릴까요?');

    await Future.delayed(const Duration(seconds: 2));
    yield Message(role: 'user', content: '오늘 하루가 좀 힘들었어요.');

    await Future.delayed(const Duration(seconds: 2));
    yield Message(role: 'assistant', content: '그랬군요. 무슨 일이 있었는지 이야기해보실래요?');
  }

/// 여기에 실제 API 연결 (WebSocket, SSE, gRPC 등) 구현 예정
}
