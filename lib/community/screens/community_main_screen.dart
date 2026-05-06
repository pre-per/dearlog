import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../providers/community_providers.dart';
import '../widgets/emotion_filter_bar.dart';
import '../widgets/post_card.dart';
import 'create_edit_post_screen.dart';
import 'post_detail_screen.dart';

/// 커뮤니티 탭의 메인 화면. 감정 필터 + 최신순 피드 + 무한 스크롤.
class CommunityMainScreen extends ConsumerStatefulWidget {
  const CommunityMainScreen({super.key});

  @override
  ConsumerState<CommunityMainScreen> createState() =>
      _CommunityMainScreenState();
}

class _CommunityMainScreenState extends ConsumerState<CommunityMainScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    // 뷰포트 한 화면 이내로 끝에 가까워지면 다음 페이지 호출.
    if (pos.pixels >= pos.maxScrollExtent - pos.viewportDimension) {
      ref.read(communityFeedProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    await ref.read(communityFeedProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(communityFeedProvider);

    return Scaffold(
      // FAB 은 Stack overlay 로 직접 띄운다 — 부모 BaseScaffold 의 BottomNavigationBar
      // 가 자식 Scaffold 의 floatingActionButton 슬롯을 덮어버려서 보이지 않기 때문.
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
          children: [
            const SizedBox(height: 8),
            const EmotionFilterBar(),
            const SizedBox(height: 8),
            Expanded(
              child: feedAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    _ErrorView(message: '$e', onRetry: _refresh),
                data: (state) {
                  if (state.posts.isEmpty) {
                    return _EmptyView(onRefresh: _refresh);
                  }
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      controller: _scrollCtrl,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: state.posts.length + 1, // +1 for footer
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i == state.posts.length) {
                          return _FeedFooter(
                            loadingMore: state.loadingMore,
                            hasMore: state.hasMore,
                          );
                        }
                        final post = state.posts[i];
                        return PostCard(
                          post: post,
                          onTap: () => _openPostDetail(post.id),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
            ),
          ),
          // 부모 네비바(약 80px) 위로 충분히 띄움.
          const Positioned(
            right: 20,
            bottom: 116,
            child: _CreatePostFab(),
          ),
        ],
      ),
    );
  }

  void _openPostDetail(String postId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
    );
  }
}

/// 우하단 글쓰기 FAB. Material `FloatingActionButton` 대신 글래스 톤 커스텀.
class _CreatePostFab extends StatelessWidget {
  const _CreatePostFab();

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateEditPostScreen()),
        );
      },
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // 어두운 네이비 거의 불투명 — cosmic 배경 위에서도 또렷이 보임.
          color: const Color(0xFF1B1B2E).withOpacity(0.92),
          border: Border.all(color: _gold.withOpacity(0.75), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: _gold.withOpacity(0.32),
              blurRadius: 18,
            ),
            // 어두운 그림자도 살짝 — 입체감.
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          IconsaxPlusBold.edit_2,
          size: 24,
          color: _gold,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 120),
          Icon(
            IconsaxPlusLinear.profile_2user,
            size: 56,
            color: Colors.white.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '아직 공개된 일기가 없어요',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '내 일기를 처음으로 공유해 보세요',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.white.withOpacity(0.6),
            ),
            const SizedBox(height: 12),
            Text(
              '피드를 불러오지 못했어요',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                '다시 시도',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedFooter extends StatelessWidget {
  final bool loadingMore;
  final bool hasMore;
  const _FeedFooter({required this.loadingMore, required this.hasMore});

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '— 끝 —',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 12,
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}
