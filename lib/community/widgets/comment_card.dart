import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/providers.dart';
import '../../shared_ui/widgets/dialog/glass_dialog.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../models/community_comment.dart';
import '../utils/relative_time.dart';
import 'community_avatar.dart';
import 'report_dialog.dart';

/// 댓글 한 개를 표시하는 카드.
///
/// - 본인 댓글: 우측 하단에 [수정] [삭제] 텍스트 액션
/// - 게시물 작성자가 본인이면 (남의 댓글에도) [삭제] 액션 (모더레이션)
/// - 수정은 인라인 모드 — 카드 안의 본문이 입력 필드로 변환됨
/// - 신고 액션은 PR6 에서 추가
class CommentCard extends ConsumerStatefulWidget {
  final CommunityComment comment;

  /// 게시물 작성자의 uid. 본인이면 자기 글의 댓글을 삭제할 수 있다.
  final String postAuthorUid;

  const CommentCard({
    super.key,
    required this.comment,
    required this.postAuthorUid,
  });

  @override
  ConsumerState<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends ConsumerState<CommentCard> {
  bool _editing = false;
  bool _saving = false;
  late TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: widget.comment.content);
  }

  @override
  void didUpdateWidget(covariant CommentCard old) {
    super.didUpdateWidget(old);
    // 외부에서 댓글 본문이 갱신되면 (다른 기기에서 수정 등) 편집 컨트롤러도 동기화.
    if (!_editing && old.comment.content != widget.comment.content) {
      _editCtrl.text = widget.comment.content;
    }
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _editCtrl.text = widget.comment.content;
      _editing = true;
    });
  }

  void _cancelEdit() {
    setState(() => _editing = false);
  }

  Future<void> _saveEdit() async {
    final newContent = _editCtrl.text.trim();
    if (newContent.isEmpty) return;
    if (newContent == widget.comment.content) {
      setState(() => _editing = false);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(communityRepositoryProvider).editComment(
            postId: widget.comment.postId,
            commentId: widget.comment.id,
            newContent: newContent,
          );
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 수정 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _report() async {
    final reason = await showReportReasonDialog(context);
    if (reason == null) return;
    final myUid = ref.read(userIdProvider);
    if (myUid == null) return;

    try {
      await ref.read(communityRepositoryProvider).reportComment(
            postId: widget.comment.postId,
            commentId: widget.comment.id,
            reporterUid: myUid,
            reason: reason,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고가 접수됐어요')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('신고 실패: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showGlassDialog<bool>(
      context: context,
      title: '댓글을 삭제할까요?',
      message: '한 번 삭제하면 되돌릴 수 없어요.',
      actions: const [
        GlassDialogAction(label: '취소', value: false),
        GlassDialogAction(
          label: '삭제',
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (ok != true) return;

    try {
      await ref.read(communityRepositoryProvider).deleteComment(
            postId: widget.comment.postId,
            commentId: widget.comment.id,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 삭제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(userIdProvider);
    final isMine = myUid != null && widget.comment.authorUid == myUid;
    final iAmPostAuthor = myUid != null && widget.postAuthorUid == myUid;
    final canReport = myUid != null && !isMine;
    final hasAnyAction = isMine || iAmPostAuthor || canReport;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommunityAvatar(
            authorUid: widget.comment.authorUid,
            displayName: widget.comment.displayName,
            isAnonymous: widget.comment.isAnonymous,
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 6),
                if (_editing) _editView() else _bodyView(),
                if (!_editing && hasAnyAction) ...[
                  const SizedBox(height: 8),
                  _actionsRow(
                    isMine: isMine,
                    canDelete: isMine || iAmPostAuthor,
                    canReport: canReport,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final c = widget.comment;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            c.displayName.isEmpty ? '익명' : c.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'GowunBatang',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatRelativeTime(c.createdAt),
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 11,
            fontFamily: 'GowunBatang',
          ),
        ),
        if (c.isEdited) ...[
          const SizedBox(width: 6),
          Text(
            '· 수정됨',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontFamily: 'GowunBatang',
            ),
          ),
        ],
      ],
    );
  }

  Widget _bodyView() {
    return Text(
      widget.comment.content,
      style: TextStyle(
        color: Colors.white.withOpacity(0.92),
        fontSize: 14,
        height: 1.55,
        fontFamily: 'GowunBatang',
      ),
    );
  }

  Widget _editView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: TextField(
            controller: _editCtrl,
            autofocus: true,
            maxLines: 5,
            minLines: 1,
            maxLength: 1000,
            cursorColor: const Color(0xFFFFD700),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.55,
              fontFamily: 'GowunBatang',
            ),
            decoration: const InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _miniAction(
              label: '취소',
              onTap: _saving ? null : _cancelEdit,
            ),
            const SizedBox(width: 12),
            _miniAction(
              label: _saving ? '저장 중...' : '저장',
              onTap: _saving ? null : _saveEdit,
              accent: const Color(0xFFFFD700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionsRow({
    required bool isMine,
    required bool canDelete,
    required bool canReport,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isMine) ...[
          _miniAction(label: '수정', onTap: _startEdit),
          const SizedBox(width: 12),
        ],
        if (canReport) ...[
          _miniAction(label: '신고', onTap: _report),
          if (canDelete) const SizedBox(width: 12),
        ],
        if (canDelete)
          _miniAction(
            label: '삭제',
            onTap: _delete,
            accent: const Color(0xFFE57373),
          ),
      ],
    );
  }

  Widget _miniAction({
    required String label,
    required VoidCallback? onTap,
    Color? accent,
  }) {
    final color = accent ?? Colors.white.withOpacity(0.65);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null ? color.withOpacity(0.4) : color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'GowunBatang',
          ),
        ),
      ),
    );
  }
}
