import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../shared_ui/utils/planet_asset_mapper.dart';
import '../../user/providers/user_stats_providers.dart';
import '../models/community_post.dart';
import '../utils/relative_time.dart';
import 'community_avatar.dart';
import 'community_nlp_block.dart';
import 'rank_badge.dart';
import 'streak_avatar_glow.dart';

/// 피드에 노출되는 게시물 카드 한 개.
///
/// 탭하면 [onTap] 호출 (PR4 에서 게시물 상세 화면으로 연결 예정).
class PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(post: post),
            const SizedBox(height: 12),
            // 일기 출신 게시물은 일기 톤 종이 배경 + 검은 글씨 — 일기 상세와 일관.
            // 직접 작성 게시물은 글래스 톤 그대로.
            if (post.isFromDiary)
              _PaperBody(title: post.title, content: post.content)
            else ...[
              if (post.title.trim().isNotEmpty) ...[
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (post.content.trim().isNotEmpty)
                Text(
                  post.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
            ],
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    post.imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white.withOpacity(0.05),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (post.nlpFilters.isNotEmpty) ...[
              const SizedBox(height: 12),
              CommunityNlpBlock(filters: post.nlpFilters, compact: true),
            ],
            const SizedBox(height: 12),
            _Footer(post: post),
          ],
        ),
      ),
    );
  }
}

/// 일기 출신 게시물의 본문 영역 — 흰 종이 배경 + 검은 글씨.
/// 일기 상세 화면(`_paperCard`) 톤과 동일.
class _PaperBody extends StatelessWidget {
  final String title;
  final String content;
  const _PaperBody({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final hasTitle = title.trim().isNotEmpty;
    final hasContent = content.trim().isNotEmpty;
    if (!hasTitle && !hasContent) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('asset/image/diary_white_page.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle) ...[
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                height: 1.5,
                fontFamily: 'GowunBatang',
              ),
            ),
            if (hasContent) const SizedBox(height: 8),
          ],
          if (hasContent)
            Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13.5,
                height: 1.6,
                fontFamily: 'GowunBatang',
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final CommunityPost post;
  const _Header({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 익명 게시물이면 작성자 본인이 게시 시점에 "익명이어도 랭크 보이기"를 켰을 때만
    // 노출. 비익명이면 항상 노출.
    final showRank = !post.isAnonymous || post.showRankIfAnonymous;

    final statsAsync = showRank
        ? ref.watch(userStatsByUidProvider(post.authorUid))
        : const AsyncValue<dynamic>.data(null);
    final stats = statsAsync.maybeWhen(data: (s) => s, orElse: () => null);
    final streak = showRank ? liveCurrentStreak(stats) : 0;
    final diaryCount = showRank ? (stats?.diaryCount ?? 0) : 0;

    final avatar = CommunityAvatar(
      authorUid: post.authorUid,
      displayName: post.displayName,
      isAnonymous: post.isAnonymous,
    );

    return Row(
      children: [
        StreakAvatarGlow(streak: streak, child: avatar),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.displayName.isEmpty ? '익명' : post.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (showRank && diaryCount > 0) ...[
                    const SizedBox(width: 6),
                    Builder(builder: (_) {
                      final badge = RankBadge.fromCount(diaryCount);
                      return badge ?? const SizedBox.shrink();
                    }),
                  ],
                ],
              ),
              Text(
                formatRelativeTime(post.createdAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // 감정 행성
        Image.asset(
          planetAssetForEmotion(post.emotion),
          width: 28,
          height: 28,
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  final CommunityPost post;
  const _Footer({required this.post});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          IconsaxPlusLinear.heart,
          size: 18,
          color: Colors.white.withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        Text(
          '${post.likeCount}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          IconsaxPlusLinear.messages_2,
          size: 18,
          color: Colors.white.withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        Text(
          '${post.commentCount}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
