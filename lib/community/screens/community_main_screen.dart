import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../user/providers/user_fetch_providers.dart';
import '../providers/community_providers.dart';
import '../providers/community_safety_providers.dart';
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
    // App Store 가이드라인 1.2 — UGC 기능은 이용 규칙(무관용 원칙) 동의 후에만
    // 사용할 수 있어야 한다. 네트워크 오류 시에는 보수적으로 통과시켜 기존
    // 사용자를 막지 않는다 (agreedTermsAt 와 같은 패턴).
    final rulesAgreed = ref.watch(communityRulesAgreedProvider).maybeWhen(
          data: (v) => v,
          error: (_, __) => true,
          orElse: () => null,
        );
    if (rulesAgreed == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!rulesAgreed) {
      return const Scaffold(body: _CommunityRulesGate());
    }

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
                  // 차단한 사용자의 글 + 신고가 누적된 글은 피드에서 숨긴다.
                  final blocked = ref.watch(blockedUidsProvider);
                  final posts = state.posts
                      .where((p) =>
                          !blocked.contains(p.authorUid) &&
                          p.reportCount < kReportHideThreshold)
                      .toList();
                  if (posts.isEmpty) {
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
                      itemCount: posts.length + 1, // +1 for footer
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i == posts.length) {
                          return _FeedFooter(
                            loadingMore: state.loadingMore,
                            hasMore: state.hasMore,
                          );
                        }
                        final post = posts[i];
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

/// 커뮤니티 첫 진입 시 이용 규칙 동의 화면.
///
/// App Store 가이드라인 1.2 — UGC 기능은 부적절 콘텐츠에 대한 무관용 원칙을
/// 담은 이용 규칙에 동의해야 사용할 수 있다. 동의 시각은 user 문서의
/// communityRulesAgreedAt 에 저장돼 기기를 바꿔도 다시 묻지 않는다.
class _CommunityRulesGate extends ConsumerStatefulWidget {
  const _CommunityRulesGate();

  @override
  ConsumerState<_CommunityRulesGate> createState() =>
      _CommunityRulesGateState();
}

class _CommunityRulesGateState extends ConsumerState<_CommunityRulesGate> {
  bool _saving = false;

  Future<void> _agree() async {
    final uid = ref.read(userIdProvider);
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    try {
      await CommunitySafetyActions.agreeCommunityRules(uid);
      // communityRulesAgreedProvider 스트림이 갱신을 감지해 화면이 전환된다.
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('잠시 후 다시 시도해 주세요: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            const Text(
              '함께 쓰는 공간이에요',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'GowunBatang',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '커뮤니티를 시작하기 전에 약속해 주세요',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontFamily: 'GowunBatang',
              ),
            ),
            const SizedBox(height: 28),
            const _RuleItem(
              emoji: '🚫',
              title: '부적절한 콘텐츠는 무관용이에요',
              body: '욕설, 혐오, 음란물, 타인 비방 등 부적절한 콘텐츠는 무관용 원칙으로 삭제되고 이용이 제한될 수 있어요.',
            ),
            const _RuleItem(
              emoji: '🚨',
              title: '신고하면 빠르게 조치해요',
              body: '신고된 콘텐츠는 운영팀이 24시간 이내에 검토해요. 신고가 누적된 글은 검토 전까지 자동으로 숨겨져요.',
            ),
            const _RuleItem(
              emoji: '🙅',
              title: '불쾌한 사용자는 차단할 수 있어요',
              body: '차단하면 그 사용자의 글과 댓글이 더 이상 보이지 않아요. 차단 목록은 커뮤니티 설정에서 관리해요.',
            ),
            const _RuleItem(
              emoji: '🔒',
              title: '개인정보를 지켜주세요',
              body: '나와 타인의 연락처, 주소 등 개인정보를 올리지 마세요.',
            ),
            const Spacer(),
            GestureDetector(
              onTap: _saving ? null : _agree,
              child: Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: Colors.white.withOpacity(_saving ? 0.5 : 1),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        '동의하고 시작하기',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  const _RuleItem({
    required this.emoji,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'GowunBatang',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                    height: 1.5,
                    fontFamily: 'GowunBatang',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
