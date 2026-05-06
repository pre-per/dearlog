import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diary/models/diary_entry.dart';
import '../providers/community_providers.dart';
import '../screens/post_detail_screen.dart';
import '../screens/share_preview_screen.dart';

/// 일기 상세 화면 우측 상단(AppBar action) 에 들어가는 커뮤니티 게시 버튼.
///
/// 글래스 톤 + 텍스트 라벨로 눈에 띄게. 상태별 라벨/색이 바뀐다:
/// - 미공개 / 조회 실패: 금색 강조 "커뮤니티 게시" → 탭 시 [SharePreviewScreen]
/// - 공개 중: 차분한 톤 + 도트 + "공개 중" → 탭 시 [PostDetailScreen] (내리기는 거기서)
/// - 로딩 / [disabled] (예: 그림 생성 중): 옅게 비활성
class CommunityShareSection extends ConsumerWidget {
  final DiaryEntry diary;

  /// 그림 생성 같은 다른 작업 중에 일시적으로 비활성화하고 싶을 때.
  final bool disabled;

  const CommunityShareSection({
    super.key,
    required this.diary,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (disabled) {
      return const _ShareTextButton(
        label: '게시',
        accent: _kGold,
        onTap: null,
      );
    }

    final asyncPost = ref.watch(publishedPostForDiaryProvider(diary.id));

    return asyncPost.when(
      loading: () => const _ShareTextButton(
        label: '게시',
        accent: _kGold,
        onTap: null,
      ),
      // 조회 실패해도 게시 시도는 가능. publishDiary 가 다시 검증함.
      error: (_, __) => _ShareTextButton(
        label: '게시',
        accent: _kGold,
        onTap: () => _openShare(context),
      ),
      data: (post) {
        if (post == null) {
          return _ShareTextButton(
            label: '게시',
            accent: _kGold,
            onTap: () => _openShare(context),
          );
        }
        // 이미 공개 중 — 라벨/도트로 구분.
        return _ShareTextButton(
          label: '공개 중',
          accent: _kGold,
          showActiveDot: true,
          onTap: () => _openPostDetail(context, post.id),
        );
      },
    );
  }

  void _openShare(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SharePreviewScreen(diary: diary)),
    );
  }

  void _openPostDetail(BuildContext context, String postId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
    );
  }
}

const Color _kGold = Color(0xFFFFD700);

class _ShareTextButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final bool showActiveDot;

  const _ShareTextButton({
    required this.label,
    required this.accent,
    required this.onTap,
    this.showActiveDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: accent.withOpacity(0.16),
                  border: Border.all(color: accent.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.18),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showActiveDot) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'GowunBatang',
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
