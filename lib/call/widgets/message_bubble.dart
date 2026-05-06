import 'package:dearlog/app.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  /// 유저 말풍선 길게 누름 — STT 오인식 수정 진입용. assistant 말풍선에는 무시된다.
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isLoading = message.role == 'assistant' && message.content == '__loading__';

    if (isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const SizedBox(
            width: 80,
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    final bubble = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? Colors.white : deep_grey_blue_color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.black87 : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    if (isUser && onLongPress != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: bubble,
      );
    }
    return bubble;
  }
}
