import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/providers.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../models/community_post.dart';
import '../models/community_comment.dart';
import '../utils/emotion_groups.dart';

/// ───── Filter state ─────

/// 현재 선택된 감정 그룹의 key. null = 전체.
final communityEmotionFilterProvider = StateProvider<String?>((ref) => null);

/// ───── Paginated feed ─────

class CommunityFeedState {
  final List<CommunityPost> posts;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  final bool loadingMore;

  const CommunityFeedState({
    required this.posts,
    required this.lastDoc,
    required this.hasMore,
    required this.loadingMore,
  });

  CommunityFeedState copyWith({
    List<CommunityPost>? posts,
    DocumentSnapshot<Map<String, dynamic>>? lastDoc,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return CommunityFeedState(
      posts: posts ?? this.posts,
      lastDoc: lastDoc ?? this.lastDoc,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

class CommunityFeedNotifier
    extends AutoDisposeAsyncNotifier<CommunityFeedState> {
  static const _pageSize = 20;

  @override
  Future<CommunityFeedState> build() async {
    // 필터가 바뀌면 자동으로 build 가 다시 실행되며 첫 페이지부터 다시 로드된다.
    final groupKey = ref.watch(communityEmotionFilterProvider);
    final emotions = findEmotionGroup(groupKey)?.emotions;

    final repo = ref.read(communityRepositoryProvider);
    final page = await repo.fetchFeed(
      limit: _pageSize,
      emotions: emotions,
    );
    return CommunityFeedState(
      posts: page.posts,
      lastDoc: page.lastDoc,
      hasMore: page.hasMore,
      loadingMore: false,
    );
  }

  /// 다음 페이지를 받아서 기존 목록 뒤에 붙인다.
  /// 더 받을 게 없거나 이미 로딩 중이면 no-op.
  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;

    state = AsyncValue.data(cur.copyWith(loadingMore: true));

    try {
      final groupKey = ref.read(communityEmotionFilterProvider);
      final emotions = findEmotionGroup(groupKey)?.emotions;

      final repo = ref.read(communityRepositoryProvider);
      final page = await repo.fetchFeed(
        limit: _pageSize,
        startAfter: cur.lastDoc,
        emotions: emotions,
      );

      state = AsyncValue.data(CommunityFeedState(
        posts: [...cur.posts, ...page.posts],
        lastDoc: page.lastDoc ?? cur.lastDoc,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (e, st) {
      // 더 불러오기 실패는 전체 화면 에러로 안 떨구고 loadingMore 만 풀어준다.
      // ignore: avoid_print
      debugPrint('[community feed] loadMore failed: $e\n$st');
      state = AsyncValue.data(cur.copyWith(loadingMore: false));
    }
  }

  /// Pull-to-refresh.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final communityFeedProvider = AsyncNotifierProvider.autoDispose<
    CommunityFeedNotifier, CommunityFeedState>(CommunityFeedNotifier.new);

/// ───── Single post / comments / likes ─────

/// 단일 게시물 라이브 구독.
final communityPostStreamProvider =
    StreamProvider.autoDispose.family<CommunityPost?, String>((ref, postId) {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.watchPost(postId);
});

/// 한 게시물의 댓글 라이브 구독.
final communityCommentsStreamProvider = StreamProvider.autoDispose
    .family<List<CommunityComment>, String>((ref, postId) {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.watchComments(postId);
});

/// 현재 사용자가 이 게시물을 좋아요 했는지 라이브 구독. 비로그인이면 false.
final communityLikedByMeProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, postId) {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return Stream.value(false);
  final repo = ref.watch(communityRepositoryProvider);
  return repo.watchLikedByMe(postId: postId, userId: uid);
});

/// 현재 사용자가 게시한 글 목록.
final myCommunityPostsStreamProvider =
    StreamProvider.autoDispose<List<CommunityPost>>((ref) {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return const Stream.empty();
  final repo = ref.watch(communityRepositoryProvider);
  return repo.watchUserPosts(uid);
});

/// 특정 일기에 대해 이미 공개된 게시물이 있는지 (일기 상세 화면의 "공유 / 이미 공개됨" 분기용).
final publishedPostForDiaryProvider =
    FutureProvider.autoDispose.family<CommunityPost?, String>(
        (ref, diaryId) async {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return null;
  final repo = ref.watch(communityRepositoryProvider);
  return repo.findPostByDiaryId(authorUid: uid, diaryId: diaryId);
});
