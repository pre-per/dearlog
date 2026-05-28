import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/providers.dart';
import '../../shared_ui/widgets/dialog/glass_dialog.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../../user/providers/user_stats_providers.dart';
import '../models/community_comment.dart';
import '../providers/reply_target_provider.dart';
import '../utils/relative_time.dart';
import 'community_avatar.dart';
import 'rank_badge.dart';
import 'report_dialog.dart';
import 'streak_avatar_glow.dart';

/// 댓글 한 개를 표시하는 카드.
///
/// - 본인 댓글: 우측 하단에 [수정] [삭제] 텍스트 액션
/// - 게시물 작성자가 본인이면 (남의 댓글에도) [삭제] 액션 (모더레이션)
/// - 답글 버튼은 최상위 댓글에만 표시 — 답글의 답글은 만들지 않는다 (1단계 정책)
/// - 수정은 인라인 모드 — 카드 안의 본문이 입력 필드로 변환됨
class CommentCard extends ConsumerStatefulWidget {
  final CommunityComment comment;

  /// 게시물 작성자의 uid. 본인이면 자기 글의 댓글을 삭제할 수 있다.
  final String postAuthorUid;

  /// 답글 카드(true)면 답글 버튼을 숨기고 카드 크기를 좀 더 작게 표시한다.
  final bool isReply;

  const CommentCard({
    super.key,
    required this.comment,
    required this.postAuthorUid,
    this.isReply = false,
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

  void _startReply() {
    // 대댓글에 답글이 달려도 들여쓰기 단계는 1단계로 고정 — 저장되는
    // parentCommentId 는 항상 최상위 댓글 id 로 통일하고, @멘션만 즉시 응답하는
    // 사람의 이름으로 채워 대화 흐름을 유지한다 (Instagram/Twitter 식 평면 스레드).
    final rootId =
        widget.comment.parentCommentId ?? widget.comment.id;
    ref.read(replyTargetProvider.notifier).setTarget(
          ReplyTarget(
            postId: widget.comment.postId,
            parentCommentId: rootId,
            parentDisplayName: widget.comment.displayName,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(userIdProvider);
    final isMine = myUid != null && widget.comment.authorUid == myUid;
    final iAmPostAuthor = myUid != null && widget.postAuthorUid == myUid;
    final canReport = myUid != null && !isMine;
    // 모든 댓글(답글 포함)에 [답글] 버튼 노출. 답글의 답글은 같은 들여쓰기 줄에
    // 평면화돼 데이터/UI 모두 1단계 정책을 깨지 않는다 (_startReply 참조).
    final canReply = myUid != null;
    final hasAnyAction = isMine || iAmPostAuthor || canReport || canReply;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(widget.isReply ? 0.035 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withOpacity(widget.isReply ? 0.07 : 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarWithGlow(
            comment: widget.comment,
            size: widget.isReply ? 26 : 32,
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
                    canReply: canReply,
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
    final showRank = !c.isAnonymous || c.showRankIfAnonymous;
    final statsAsync = showRank
        ? ref.watch(userStatsByUidProvider(c.authorUid))
        : const AsyncValue<dynamic>.data(null);
    final stats = statsAsync.maybeWhen(data: (s) => s, orElse: () => null);
    final diaryCount = showRank ? (stats?.diaryCount ?? 0) : 0;
    final badge =
        showRank && diaryCount > 0 ? RankBadge.fromCount(diaryCount) : null;

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
        if (badge != null) ...[
          const SizedBox(width: 5),
          badge,
        ],
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
    required bool canReply,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (canReply) ...[
          _miniAction(label: '답글', onTap: _startReply),
          if (isMine || canReport || canDelete) const SizedBox(width: 12),
        ],
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

/// 댓글 작성자 아바타 + 스트릭 글로우. 익명이면서 작성자가 토글을 꺼둔 경우엔
/// 글로우 없이 평범한 아바타만 노출한다.
class _AvatarWithGlow extends ConsumerWidget {
  final CommunityComment comment;
  final double size;

  const _AvatarWithGlow({required this.comment, required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = CommunityAvatar(
      authorUid: comment.authorUid,
      displayName: comment.displayName,
      isAnonymous: comment.isAnonymous,
      size: size,
    );
    final showRank = !comment.isAnonymous || comment.showRankIfAnonymous;
    if (!showRank) return avatar;

    final stats =
        ref.watch(userStatsByUidProvider(comment.authorUid)).maybeWhen(
              data: (s) => s,
              orElse: () => null,
            );
    final streak = liveCurrentStreak(stats);
    return StreakAvatarGlow(streak: streak, child: avatar, avatarSize: size);
  }
}
