import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 댓글 입력바가 답글 작성 모드인지 여부 — 비어있으면 일반 댓글 작성, 채워져
/// 있으면 그 댓글에 대한 답글로 동작한다.
class ReplyTarget {
  final String postId;
  final String parentCommentId;

  /// 답글 카드의 "@xxx" 멘션과 입력바 상단 헤더에 표시되는 이름. 익명 댓글의
  /// 답글이면 '익명'.
  final String parentDisplayName;

  const ReplyTarget({
    required this.postId,
    required this.parentCommentId,
    required this.parentDisplayName,
  });
}

/// 한 화면(게시물 상세)에 하나의 답글 대상만 유지하면 충분하다. 다른 게시물로
/// 이동하면 inputBar 가 다시 마운트되며 [ReplyTargetController.clear] 가
/// 호출되므로 누수 없음.
class ReplyTargetController extends Notifier<ReplyTarget?> {
  @override
  ReplyTarget? build() => null;

  void setTarget(ReplyTarget target) {
    state = target;
  }

  void clear() {
    state = null;
  }
}

final replyTargetProvider =
    NotifierProvider<ReplyTargetController, ReplyTarget?>(
        ReplyTargetController.new);
