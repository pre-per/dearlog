import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/providers.dart';
import '../../core/base_scaffold.dart';
import '../../diary/models/diary_entry.dart';
import '../../shared_ui/widgets/dialog/glass_dialog.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../models/community_post.dart';
import '../providers/community_providers.dart';
import '../widgets/post_card.dart';

/// 일기를 커뮤니티에 공개하기 전 미리보기 + 편집 화면.
///
/// - 입력값(제목/내용/익명 여부)이 바뀌면 상단의 카드 미리보기에 즉시 반영된다.
/// - 게시 직전 한 번 더 글래스 다이얼로그로 확인을 받는다.
class SharePreviewScreen extends ConsumerStatefulWidget {
  final DiaryEntry diary;
  const SharePreviewScreen({super.key, required this.diary});

  @override
  ConsumerState<SharePreviewScreen> createState() =>
      _SharePreviewScreenState();
}

class _SharePreviewScreenState extends ConsumerState<SharePreviewScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  bool _isAnonymous = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.diary.title)
      ..addListener(_onChanged);
    _contentCtrl = TextEditingController(text: widget.diary.content)
      ..addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_publishing) return;

    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) {
      _snack('제목이나 내용 중 하나는 채워주세요');
      return;
    }

    final user = ref.read(userProvider).valueOrNull;
    if (user == null) {
      _snack('사용자 정보를 불러오지 못했어요');
      return;
    }

    final ok = await showGlassDialog<bool>(
      context: context,
      title: '커뮤니티에 공개할까요?',
      message: _isAnonymous
          ? '익명으로 게시돼요.\n다른 사람들이 댓글과 좋아요를 남길 수 있어요.'
          : '"${user.profile.nickname}" 으로 게시돼요.\n다른 사람들이 댓글과 좋아요를 남길 수 있어요.',
      actions: const [
        GlassDialogAction(label: '취소', value: false),
        GlassDialogAction(label: '공개하기', value: true),
      ],
    );
    if (ok != true) return;

    setState(() => _publishing = true);
    try {
      await ref.read(communityRepositoryProvider).publishDiary(
            authorUid: user.id,
            authorNickname: user.profile.nickname,
            isAnonymous: _isAnonymous,
            diary: widget.diary,
            overrideTitle: title,
            overrideContent: content,
          );

      // 피드와 일기 상세의 공개 상태 캐시 무효화
      ref.invalidate(communityFeedProvider);
      ref.invalidate(publishedPostForDiaryProvider(widget.diary.id));

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('커뮤니티에 공개됐어요')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      _snack('공개에 실패했어요: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).valueOrNull;
    final nickname = user?.profile.nickname ?? '';

    // 실시간 미리보기용 임시 게시물 (저장되지 않음)
    final previewPost = CommunityPost(
      id: '_preview',
      authorUid: user?.id ?? '',
      authorNicknameSnapshot: nickname,
      isAnonymous: _isAnonymous,
      originalDiaryId: widget.diary.id,
      title: _titleCtrl.text,
      content: _contentCtrl.text,
      emotion: widget.diary.emotion,
      imageUrls: widget.diary.imageUrls,
      diaryDate: widget.diary.date,
      createdAt: DateTime.now(),
    );

    return BaseScaffold(
      appBar: AppBar(
        title: const Text(
          '커뮤니티에 공유',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'GowunBatang',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('이렇게 공개돼요'),
                    const SizedBox(height: 10),
                    PostCard(post: previewPost),
                    const SizedBox(height: 28),
                    _sectionLabel('표시 이름'),
                    const SizedBox(height: 10),
                    _IdentityToggle(
                      nickname: nickname.isEmpty ? '닉네임' : nickname,
                      isAnonymous: _isAnonymous,
                      onChanged: (v) => setState(() => _isAnonymous = v),
                    ),
                    const SizedBox(height: 28),
                    _sectionLabel('제목'),
                    const SizedBox(height: 10),
                    _GlassTextField(
                      controller: _titleCtrl,
                      hint: '제목 (선택)',
                      maxLines: 1,
                      maxLength: 100,
                    ),
                    const SizedBox(height: 24),
                    _sectionLabel('내용'),
                    const SizedBox(height: 10),
                    _GlassTextField(
                      controller: _contentCtrl,
                      hint: '내용을 입력해 주세요',
                      maxLines: 10,
                      maxLength: 5000,
                    ),
                    const SizedBox(height: 16),
                    const _NoticeBox(),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _PublishButton(
                  loading: _publishing,
                  onTap: _publish,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          fontFamily: 'GowunBatang',
        ),
      );
}

/// 닉네임 / 익명 두 개 옵션 토글. 선택된 쪽은 골드 강조.
class _IdentityToggle extends StatelessWidget {
  final String nickname;
  final bool isAnonymous;
  final ValueChanged<bool> onChanged;
  const _IdentityToggle({
    required this.nickname,
    required this.isAnonymous,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleChip(
            label: nickname,
            sublabel: '닉네임으로',
            selected: !isAnonymous,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ToggleChip(
            label: '익명',
            sublabel: '이름 숨기고',
            selected: isAnonymous,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? _gold.withOpacity(0.16)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _gold : Colors.white.withOpacity(0.12),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              sublabel,
              style: TextStyle(
                color: (selected ? _gold : Colors.white).withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFamily: 'GowunBatang',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? _gold : Colors.white,
                fontSize: 14,
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

/// 글래스 스타일 텍스트 입력 필드. 머티리얼 underline / outlined 보더 없음.
class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int maxLength;
  const _GlassTextField({
    required this.controller,
    required this.hint,
    required this.maxLines,
    required this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: 1,
        maxLength: maxLength,
        cursorColor: const Color(0xFFFFD700),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14.5,
          height: 1.6,
          fontFamily: 'GowunBatang',
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: InputBorder.none,
          counterText: '',
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontFamily: 'GowunBatang',
          ),
        ),
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bullet('AI 분석 · 편지 · 대화 기록은 공개되지 않아요'),
          const SizedBox(height: 6),
          _bullet('같은 일기는 한 번에 하나의 게시물만 공개할 수 있어요'),
          const SizedBox(height: 6),
          _bullet('게시 후 마음이 바뀌면 일기 화면에서 언제든 내릴 수 있어요'),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, right: 8),
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 12,
              height: 1.5,
              fontFamily: 'GowunBatang',
            ),
          ),
        ),
      ],
    );
  }
}

class _PublishButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _PublishButton({required this.loading, required this.onTap});

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _gold.withOpacity(loading ? 0.10 : 0.20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _gold.withOpacity(loading ? 0.3 : 0.6),
            width: 1.2,
          ),
          boxShadow: loading
              ? null
              : [
                  BoxShadow(
                    color: _gold.withOpacity(0.2),
                    blurRadius: 14,
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(_gold),
                  ),
                )
              : const Text(
                  '공개하기',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    fontFamily: 'GowunBatang',
                  ),
                ),
        ),
      ),
    );
  }
}
