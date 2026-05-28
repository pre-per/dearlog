import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/providers.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../providers/anonymous_default_provider.dart';
import '../providers/reply_target_provider.dart';

/// 게시물 상세 하단에 고정되는 댓글 입력 바.
///
/// - 키보드가 올라오면 `Scaffold.bottomNavigationBar` 슬롯에 들어가 있어 자동으로 같이 올라간다.
/// - 입력란 위에 작은 "익명으로 작성" 토글 — 익명 기본값 [anonymousDefaultProvider] 와 동기화.
/// - 답글 모드일 때는 상단에 "@xxx 에게 답글" 헤더가 뜨고 본문 앞에 자동으로
///   "@xxx " 멘션이 채워진다.
/// - 비로그인 / 닉네임 미설정 상태에서는 안내 텍스트로 대체.
class CommentInputBar extends ConsumerStatefulWidget {
  final String postId;
  const CommentInputBar({super.key, required this.postId});

  @override
  ConsumerState<CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends ConsumerState<CommentInputBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;
  String? _lastReplyTargetId;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
    // 다른 게시물 상세에서 남긴 답글 대상이 새 화면에 끌려오지 않도록 초기화.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cur = ref.read(replyTargetProvider);
      if (cur != null && cur.postId != widget.postId) {
        ref.read(replyTargetProvider.notifier).clear();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canSend => _ctrl.text.trim().isNotEmpty && !_sending;

  /// 답글 대상이 바뀌면 멘션 prefix 를 채우고 포커스 — build 안에서 ref.listen
  /// 으로 호출한다.
  void _applyReplyTarget(ReplyTarget? target) {
    if (target == null) {
      // 답글 모드 해제 시 멘션 prefix 제거
      if (_lastReplyTargetId != null && _ctrl.text.startsWith('@')) {
        _ctrl.clear();
      }
      _lastReplyTargetId = null;
      return;
    }
    if (_lastReplyTargetId == target.parentCommentId) return;
    _lastReplyTargetId = target.parentCommentId;
    final mention = '@${target.parentDisplayName} ';
    _ctrl.text = mention;
    _ctrl.selection = TextSelection.collapsed(offset: mention.length);
    // 포커스를 부여해 키보드 자동 노출.
    FocusScope.of(context).requestFocus(_focus);
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final user = ref.read(userProvider).valueOrNull;
    if (user == null) return;

    final text = _ctrl.text.trim();
    final isAnonymous = ref.read(anonymousDefaultProvider);
    final replyTarget = ref.read(replyTargetProvider);

    setState(() => _sending = true);
    try {
      await ref.read(communityRepositoryProvider).addComment(
            postId: widget.postId,
            authorUid: user.id,
            authorNickname: user.profile.nickname,
            isAnonymous: isAnonymous,
            content: text,
            parentCommentId: replyTarget?.parentCommentId,
            parentNicknameSnapshot: replyTarget?.parentDisplayName,
            showRankIfAnonymous: user.preferences.showRankWhenAnonymous,
          );
      _ctrl.clear();
      // 답글 모드 종료 — 다음 입력은 일반 댓글로 시작
      if (replyTarget != null) {
        ref.read(replyTargetProvider.notifier).clear();
      }
      // 키보드는 유지 — 연달아 댓글 달기 편하게
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 작성에 실패했어요: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).valueOrNull;
    final loggedIn = user != null;
    final isAnonymous = ref.watch(anonymousDefaultProvider);
    final replyTarget = ref.watch(replyTargetProvider);

    // 답글 대상이 바뀌면 멘션 채우기. build 안의 schedule 로 동기화 시점 안정화.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyReplyTarget(replyTarget);
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: !loggedIn
              ? _disabledHint()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (replyTarget != null)
                      _ReplyHeader(
                        targetName: replyTarget.parentDisplayName,
                        onCancel: () =>
                            ref.read(replyTargetProvider.notifier).clear(),
                      ),
                    _AnonymousToggle(
                      isAnonymous: isAnonymous,
                      onTap: () => ref
                          .read(anonymousDefaultProvider.notifier)
                          .toggle(),
                    ),
                    const SizedBox(height: 6),
                    _inputRow(isReply: replyTarget != null),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _inputRow({required bool isReply}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              cursorColor: const Color(0xFFFFD700),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
                fontFamily: 'GowunBatang',
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                counterText: '',
                hintText: isReply ? '답글 남기기...' : '댓글 남기기...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontFamily: 'GowunBatang',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _SendButton(enabled: _canSend, sending: _sending, onTap: _send),
      ],
    );
  }

  Widget _disabledHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          '로그인 후에 댓글을 남길 수 있어요',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 13,
            fontFamily: 'GowunBatang',
          ),
        ),
      ),
    );
  }
}

class _ReplyHeader extends StatelessWidget {
  final String targetName;
  final VoidCallback onCancel;
  const _ReplyHeader({required this.targetName, required this.onCancel});

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _gold.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.reply_rounded, size: 13, color: _gold),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '$targetName 님에게 답글',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onCancel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.white.withOpacity(0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnonymousToggle extends StatelessWidget {
  final bool isAnonymous;
  final VoidCallback onTap;
  const _AnonymousToggle({required this.isAnonymous, required this.onTap});

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isAnonymous ? _gold : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color:
                      isAnonymous ? _gold : Colors.white.withOpacity(0.45),
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: isAnonymous
                  ? const Icon(Icons.check, size: 10, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              '익명으로 작성',
              style: TextStyle(
                color: isAnonymous
                    ? _gold
                    : Colors.white.withOpacity(0.65),
                fontSize: 12,
                fontWeight: isAnonymous ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'GowunBatang',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool sending;
  final VoidCallback onTap;
  const _SendButton({
    required this.enabled,
    required this.sending,
    required this.onTap,
  });

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _gold.withOpacity(0.18),
            border: Border.all(color: _gold.withOpacity(0.55)),
          ),
          alignment: Alignment.center,
          child: sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_gold),
                  ),
                )
              : const Icon(Icons.arrow_upward, size: 18, color: _gold),
        ),
      ),
    );
  }
}
