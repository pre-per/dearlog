import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

import '../../app/di/providers.dart';
import '../../core/base_scaffold.dart';
import '../../shared_ui/utils/planet_asset_mapper.dart';
import '../../shared_ui/widgets/dialog/glass_dialog.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../models/community_post.dart';
import '../providers/community_providers.dart';
import '../utils/relative_time.dart';
import '../widgets/comment_card.dart';
import '../widgets/comment_input_bar.dart';
import '../widgets/community_avatar.dart';
import '../widgets/like_button.dart';
import '../widgets/report_dialog.dart';
import 'create_edit_post_screen.dart';

/// 공개 게시물 상세 화면.
///
/// - 게시물 본문은 라이브 구독 — 다른 기기에서 좋아요/댓글 카운트가 변하면 자동 갱신.
/// - 작성자 본인이면 AppBar 우측에 "내리기" 액션 노출.
/// - 댓글 영역은 PR5 에서 채움 (지금은 카운트 + placeholder).
class PostDetailScreen extends ConsumerWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(communityPostStreamProvider(postId));
    final myUid = ref.watch(userIdProvider);

    return BaseScaffold(
      appBar: AppBar(
        title: const Text(
          '공개 게시물',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'GowunBatang',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          postAsync.maybeWhen(
            data: (post) {
              if (post == null || myUid == null) {
                return const SizedBox.shrink();
              }
              if (post.authorUid == myUid) {
                // 본인 글 — 수정 + 내리기 두 액션
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _EditPostAction(post: post),
                    _TakeDownAction(post: post),
                  ],
                );
              }
              return _ReportPostAction(post: post);
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      // body 안에 Column(Expanded(scroll), inputBar) 구조로 두면 Scaffold 의
      // resizeToAvoidBottomInset 동작에 의해 body 영역이 키보드 높이만큼 줄어들고,
      // Column 마지막 자식인 입력바가 자연스럽게 키보드 바로 위에 위치한다.
      // bottomNavigationBar 슬롯에 두면 키보드에 가려지는 Flutter 동작이 있어서 피한다.
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _MessageView(
          title: '게시물을 불러오지 못했어요',
          subtitle: '$e',
        ),
        data: (post) {
          if (post == null) {
            return const _MessageView(
              title: '삭제된 게시물이에요',
              subtitle: '작성자가 게시물을 내렸거나 삭제됐어요',
            );
          }
          return Column(
            children: [
              Expanded(child: _PostBody(post: post)),
              CommentInputBar(postId: post.id),
            ],
          );
        },
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  final CommunityPost post;
  const _PostBody({required this.post});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(post: post),
          const SizedBox(height: 20),
          // 일기 출신 게시물은 흰 종이 배경 + 검은 글씨 (일기 상세와 동일 톤).
          // 직접 작성 게시물은 글래스(흰 글씨).
          if (post.isFromDiary)
            _PaperFullBody(title: post.title, content: post.content)
          else ...[
            if (post.title.trim().isNotEmpty) ...[
              Text(
                post.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  fontFamily: 'GowunBatang',
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (post.content.trim().isNotEmpty)
              Text(
                post.content,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 15,
                  height: 1.7,
                  fontFamily: 'GowunBatang',
                ),
              ),
          ],
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 20),
            for (int i = 0; i < post.imageUrls.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _PostImage(url: post.imageUrls[i]),
            ],
          ],
          const SizedBox(height: 20),
          // 일기 원본 작성일 (작성 시점 vs 게시 시점 구분)
          Text(
            '${DateFormat('yyyy.MM.dd', 'ko_KR').format(post.diaryDate)} 작성',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontFamily: 'GowunBatang',
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              LikeButton(post: post),
              const SizedBox(width: 12),
              _CommentCountChip(count: post.commentCount),
            ],
          ),
          const SizedBox(height: 28),
          _CommentsSection(post: post),
        ],
      ),
    );
  }
}

/// 일기 출신 게시물의 본문 영역 — 흰 종이 배경 + 검은 글씨.
/// `lib/diary/screens/diary_detail_screen.dart` 의 `_paperCard` 톤을 재현.
class _PaperFullBody extends StatelessWidget {
  final String title;
  final String content;
  const _PaperFullBody({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final hasTitle = title.trim().isNotEmpty;
    final hasContent = content.trim().isNotEmpty;
    if (!hasTitle && !hasContent) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('asset/image/diary_white_page.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTitle) ...[
            Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.5,
                fontFamily: 'GowunBatang',
              ),
            ),
            if (hasContent) const SizedBox(height: 12),
          ],
          if (hasContent)
            Text(
              content,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14.5,
                height: 1.7,
                fontFamily: 'GowunBatang',
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final CommunityPost post;
  const _Header({required this.post});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CommunityAvatar(
          authorUid: post.authorUid,
          displayName: post.displayName,
          isAnonymous: post.isAnonymous,
          size: 44,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.displayName.isEmpty ? '익명' : post.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'GowunBatang',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatRelativeTime(post.createdAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12,
                  fontFamily: 'GowunBatang',
                ),
              ),
            ],
          ),
        ),
        Image.asset(
          planetAssetForEmotion(post.emotion),
          width: 36,
          height: 36,
        ),
      ],
    );
  }
}

class _PostImage extends StatelessWidget {
  final String url;
  const _PostImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 240,
            color: Colors.white.withOpacity(0.04),
            alignment: Alignment.center,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          color: Colors.white.withOpacity(0.05),
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: Colors.white24,
          ),
        ),
      ),
    );
  }
}

class _CommentCountChip extends StatelessWidget {
  final int count;
  const _CommentCountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            IconsaxPlusLinear.messages_2,
            size: 18,
            color: Colors.white.withOpacity(0.85),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'GowunBatang',
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSection extends ConsumerWidget {
  final CommunityPost post;
  const _CommentsSection({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync =
        ref.watch(communityCommentsStreamProvider(post.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '댓글',
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            fontFamily: 'GowunBatang',
          ),
        ),
        const SizedBox(height: 12),
        commentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '댓글을 불러오지 못했어요',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontFamily: 'GowunBatang',
                ),
              ),
            ),
          ),
          data: (comments) {
            if (comments.isEmpty) {
              return _emptyState();
            }
            return Column(
              children: [
                for (int i = 0; i < comments.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  CommentCard(
                    comment: comments[i],
                    postAuthorUid: post.authorUid,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Text(
            '아직 댓글이 없어요',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'GowunBatang',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '첫 댓글을 남겨 보세요',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontFamily: 'GowunBatang',
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final String title;
  final String subtitle;
  const _MessageView({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'GowunBatang',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontFamily: 'GowunBatang',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditPostAction extends StatelessWidget {
  final CommunityPost post;
  const _EditPostAction({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CreateEditPostScreen(existing: post),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: Text(
            '수정',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'GowunBatang',
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportPostAction extends ConsumerWidget {
  final CommunityPost post;
  const _ReportPostAction({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _handle(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Text(
            '신고',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'GowunBatang',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref) async {
    final reason = await showReportReasonDialog(context);
    if (reason == null) return;
    final myUid = ref.read(userIdProvider);
    if (myUid == null) return;

    try {
      await ref.read(communityRepositoryProvider).reportPost(
            postId: post.id,
            reporterUid: myUid,
            reason: reason,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고가 접수됐어요')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('신고 실패: $e')),
        );
      }
    }
  }
}

class _TakeDownAction extends ConsumerWidget {
  final CommunityPost post;
  const _TakeDownAction({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _handleTakeDown(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Text(
            '내리기',
            style: TextStyle(
              color: const Color(0xFFE57373).withOpacity(0.95),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'GowunBatang',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTakeDown(BuildContext context, WidgetRef ref) async {
    final ok = await showGlassDialog<bool>(
      context: context,
      title: '게시물을 내릴까요?',
      message: '댓글과 좋아요도 함께 사라져요.\n원본 일기는 그대로 유지돼요.',
      actions: const [
        GlassDialogAction(label: '취소', value: false),
        GlassDialogAction(
          label: '내리기',
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (ok != true) return;

    try {
      await ref.read(communityRepositoryProvider).takeDownPost(post.id);
      ref.invalidate(communityFeedProvider);
      ref.invalidate(publishedPostForDiaryProvider(post.originalDiaryId));
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시물을 내렸어요')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내리기 실패: $e')),
        );
      }
    }
  }
}
