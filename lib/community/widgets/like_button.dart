import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../app/di/providers.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../models/community_post.dart';
import '../providers/community_providers.dart';

/// 게시물 상세 하단의 좋아요 토글 버튼.
///
/// 좋아요 상태는 Firestore 라이브 구독이라 토글 호출 후 별도 상태 관리 없이
/// 즉시 화면에 반영된다. 비로그인 상태에서는 비활성.
class LikeButton extends ConsumerWidget {
  final CommunityPost post;
  const LikeButton({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(communityLikedByMeProvider(post.id));
    final liked = likedAsync.valueOrNull ?? false;
    final uid = ref.watch(userIdProvider);

    final accent = liked
        ? const Color(0xFFFF7B8C)
        : Colors.white.withOpacity(0.85);

    return GestureDetector(
      onTap: uid == null
          ? null
          : () => ref
              .read(communityRepositoryProvider)
              .toggleLike(postId: post.id, userId: uid),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: liked
              ? const Color(0xFFFF7B8C).withOpacity(0.12)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: liked
                ? const Color(0xFFFF7B8C).withOpacity(0.5)
                : Colors.white.withOpacity(0.15),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? IconsaxPlusBold.heart : IconsaxPlusLinear.heart,
              size: 20,
              color: accent,
            ),
            const SizedBox(width: 8),
            Text(
              '${post.likeCount}',
              style: TextStyle(
                color: accent,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'GowunBatang',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
