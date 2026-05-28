import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/providers.dart';
import '../../core/base_scaffold.dart';
import '../../shared_ui/widgets/dialog/glass_dialog.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../models/community_post.dart';
import '../providers/anonymous_default_provider.dart';
import '../providers/community_providers.dart';
import '../utils/emotion_groups.dart';
import '../widgets/post_card.dart';
import '../widgets/standalone_share_options_panel.dart';

/// 일기 없이 커뮤니티에 직접 글을 쓰거나, 본인이 게시한 글을 수정하는 화면.
///
/// - `existing == null` 이면 **신규 작성**, non-null 이면 **수정** 모드.
/// - 일기 공유 게시물의 수정도 이 화면을 재사용한다 (수정 모드 진입 시 호출).
class CreateEditPostScreen extends ConsumerStatefulWidget {
  final CommunityPost? existing;
  const CreateEditPostScreen({super.key, this.existing});

  @override
  ConsumerState<CreateEditPostScreen> createState() =>
      _CreateEditPostScreenState();
}

class _CreateEditPostScreenState extends ConsumerState<CreateEditPostScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  String? _emotionGroupKey;
  late StandaloneShareOptions _options;
  bool _saving = false;
  // 수정 모드 진입 시 기존 익명 설정을 글로벌 provider 에 한 번만 반영하기 위한 가드.
  bool _appliedExistingAnonymous = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _titleCtrl = TextEditingController(text: ex?.title ?? '')
      ..addListener(_onChanged);
    _contentCtrl = TextEditingController(text: ex?.content ?? '')
      ..addListener(_onChanged);
    // 기존 emotion 문자열 → 그룹 키 역추적 (수정 모드에서 칩 활성화 표시용)
    if (ex != null && ex.emotion.trim().isNotEmpty) {
      for (final g in emotionGroups) {
        if (g.emotions.contains(ex.emotion)) {
          _emotionGroupKey = g.key;
          break;
        }
      }
    }
    _options = StandaloneShareOptions.initial(
      hasEmotion: _emotionGroupKey != null,
    );
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    final title = _options.includeTitle ? _titleCtrl.text.trim() : '';
    final content = _options.includeContent ? _contentCtrl.text.trim() : '';
    if (title.isEmpty && content.isEmpty) {
      _snack('제목이나 내용 중 하나는 채워주세요');
      return;
    }

    final user = ref.read(userProvider).valueOrNull;
    if (user == null) {
      _snack('사용자 정보를 불러오지 못했어요');
      return;
    }

    final group = findEmotionGroup(_emotionGroupKey);
    // 그룹 대표 감정으로 저장 — 행성 매핑이 한 그룹의 모든 단어를 같은 행성으로 처리하니
    // 어떤 단어를 골라도 동일하게 보인다. 첫 단어를 대표로. 토글 OFF 면 빈 문자열.
    final emotion =
        _options.includeEmotion ? (group?.emotions.first ?? '') : '';
    final isAnonymous = ref.read(anonymousDefaultProvider);

    final ok = await showGlassDialog<bool>(
      context: context,
      title: _isEdit ? '게시물을 수정할까요?' : '커뮤니티에 게시할까요?',
      message: isAnonymous
          ? '익명으로 게시돼요.\n다른 사람들이 댓글과 좋아요를 남길 수 있어요.'
          : '"${user.profile.nickname}" 으로 게시돼요.\n다른 사람들이 댓글과 좋아요를 남길 수 있어요.',
      actions: [
        const GlassDialogAction(label: '취소', value: false),
        GlassDialogAction(
            label: _isEdit ? '저장' : '게시하기', value: true),
      ],
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      if (_isEdit) {
        await repo.editPost(
          postId: widget.existing!.id,
          title: title,
          content: content,
          emotion: emotion,
          isAnonymous: isAnonymous,
        );
        ref.invalidate(communityPostStreamProvider(widget.existing!.id));
      } else {
        await repo.createStandalonePost(
          authorUid: user.id,
          authorNickname: user.profile.nickname,
          isAnonymous: isAnonymous,
          title: title,
          content: content,
          emotion: emotion,
          showRankIfAnonymous: user.preferences.showRankWhenAnonymous,
        );
      }
      ref.invalidate(communityFeedProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_isEdit ? '게시물이 수정됐어요' : '커뮤니티에 게시됐어요')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('${_isEdit ? "수정" : "게시"}에 실패했어요: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).valueOrNull;
    final nickname = user?.profile.nickname ?? '';
    final isAnonymous = ref.watch(anonymousDefaultProvider);

    // 수정 모드 진입 첫 빌드에 기존 게시물의 익명 설정을 글로벌 provider 로
    // 한 번만 반영. 이후엔 사용자가 토글하면 provider 가 단일 진실로 동작.
    if (_isEdit && !_appliedExistingAnonymous) {
      _appliedExistingAnonymous = true;
      final existingAnon = widget.existing!.isAnonymous;
      if (existingAnon != isAnonymous) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(anonymousDefaultProvider.notifier)
              .setAnonymous(existingAnon);
        });
      }
    }

    final group = findEmotionGroup(_emotionGroupKey);
    final previewPost = CommunityPost(
      id: widget.existing?.id ?? '_preview',
      authorUid: user?.id ?? '',
      authorNicknameSnapshot: nickname,
      isAnonymous: isAnonymous,
      originalDiaryId: widget.existing?.originalDiaryId ?? '',
      title: _options.includeTitle ? _titleCtrl.text : '',
      content: _options.includeContent ? _contentCtrl.text : '',
      emotion: _options.includeEmotion ? (group?.emotions.first ?? '') : '',
      imageUrls: widget.existing?.imageUrls ?? const [],
      diaryDate: widget.existing?.diaryDate ?? DateTime.now(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      nlpFilters: widget.existing?.nlpFilters ?? const [],
    );

    return BaseScaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? '게시물 수정' : '글 작성',
          style: const TextStyle(
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
                    _sectionLabel('이렇게 보여요'),
                    const SizedBox(height: 10),
                    PostCard(post: previewPost),
                    const SizedBox(height: 28),
                    _sectionLabel('공유할 정보'),
                    const SizedBox(height: 10),
                    StandaloneShareOptionsPanel(
                      options: _options,
                      onChanged: (next) => setState(() => _options = next),
                    ),
                    const SizedBox(height: 28),
                    _sectionLabel('표시 이름'),
                    const SizedBox(height: 10),
                    _IdentityToggle(
                      nickname: nickname.isEmpty ? '닉네임' : nickname,
                      isAnonymous: isAnonymous,
                      onChanged: (v) => ref
                          .read(anonymousDefaultProvider.notifier)
                          .setAnonymous(v),
                    ),
                    if (_options.includeEmotion) ...[
                      const SizedBox(height: 28),
                      _sectionLabel('감정 (선택)'),
                      const SizedBox(height: 10),
                      _EmotionPicker(
                        selected: _emotionGroupKey,
                        onChanged: (v) =>
                            setState(() => _emotionGroupKey = v),
                      ),
                    ],
                    if (_options.includeTitle) ...[
                      const SizedBox(height: 28),
                      _sectionLabel('제목'),
                      const SizedBox(height: 10),
                      _GlassTextField(
                        controller: _titleCtrl,
                        hint: '제목 (선택)',
                        maxLines: 1,
                        maxLength: 100,
                      ),
                    ],
                    if (_options.includeContent) ...[
                      const SizedBox(height: 24),
                      _sectionLabel('내용'),
                      const SizedBox(height: 10),
                      _GlassTextField(
                        controller: _contentCtrl,
                        hint: '내용을 입력해 주세요',
                        maxLines: 10,
                        maxLength: 5000,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _SubmitButton(
                  label: _isEdit ? '저장하기' : '게시하기',
                  loading: _saving,
                  onTap: _submit,
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

/// 감정 그룹 5개 + "선택 안 함" 칩 row.
class _EmotionPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;
  const _EmotionPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            label: '선택 안 함',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final g in emotionGroups) ...[
            const SizedBox(width: 8),
            _Chip(
              label: g.label,
              moonAsset: 'asset/image/moon_images/${g.moonAsset}.png',
              selected: selected == g.key,
              onTap: () =>
                  onChanged(selected == g.key ? null : g.key),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String? moonAsset;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.moonAsset,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFFFFD700).withOpacity(0.18)
        : Colors.white.withOpacity(0.06);
    final borderColor = selected
        ? const Color(0xFFFFD700)
        : Colors.white.withOpacity(0.15);
    final textColor = selected
        ? const Color(0xFFFFD700)
        : Colors.white.withOpacity(0.85);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (moonAsset != null) ...[
              Image.asset(moonAsset!, width: 18, height: 18),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'GowunBatang',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _SubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

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
              : Text(
                  label,
                  style: const TextStyle(
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
