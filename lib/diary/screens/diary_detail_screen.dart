import 'dart:ui';
import 'package:dearlog/app.dart';
import 'package:dearlog/community/widgets/community_share_section.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:dearlog/analysis/widget/today_summary_card.dart';

class DiaryDetailScreen extends ConsumerStatefulWidget {
  final DiaryEntry diary;

  const DiaryDetailScreen({super.key, required this.diary});

  @override
  ConsumerState<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends ConsumerState<DiaryDetailScreen> {
  late DiaryEntry _diary;
  bool _deleting = false;
  bool _generatingIllustration = false;

  @override
  void initState() {
    super.initState();
    _diary = widget.diary;
    // CBT 지표 — AI 산출물(일기) 조회.
    // ignore: unawaited_futures
    AnalyticsService.logReportViewed(
      source: 'diary_detail',
      diaryId: _diary.id,
      hasImage: _diary.imageUrls.isNotEmpty,
    );
  }

  Future<bool> _confirmExitDuringGeneration() async {
    final ok = await showGlassDialog<bool>(
      context: context,
      title: '그림 생성을 취소할까요?',
      message: '지금 나가면 그리고 있던 그림이 사라져요.\n일기는 그대로 유지돼요.',
      actions: const [
        GlassDialogAction(label: '계속 만들기', value: false),
        GlassDialogAction(label: '나가기', value: true, isDestructive: true),
      ],
    );
    return ok == true;
  }

  Future<void> _updateDiary(DiaryEntry updated) async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    await ref.read(diaryRepositoryProvider).saveDiary(userId, updated);
    setState(() => _diary = updated);
  }

  Future<void> _confirmDelete() async {
    if (_deleting) return;
    final ok = await showGlassDialog<bool>(
      context: context,
      title: '일기를 삭제할까요?',
      message: '일기에 첨부된 그림과 편지, 분석 결과가 모두 사라져요.\n이 작업은 되돌릴 수 없어요.',
      actions: const [
        GlassDialogAction(label: '취소', value: false),
        GlassDialogAction(label: '삭제', value: true, isDestructive: true),
      ],
    );
    if (ok != true) return;

    setState(() => _deleting = true);
    try {
      final userId = ref.read(userIdProvider);
      if (userId == null) return;

      // 잠금 편지 알림 취소
      final scheduler = LetterScheduler();
      for (final l in _diary.letters) {
        if (l.isLocked) {
          await scheduler.cancel(l);
        }
      }

      await ref.read(diaryRepositoryProvider).deleteDiary(userId, _diary.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제에 실패했어요: $e'),
          backgroundColor: const Color(0xFF1E1E2E),
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 그림 생성 중에는 시스템 백 / 앱바 ← / iOS 가장자리 스와이프 모두 차단,
      // onPopInvokedWithResult에서 경고 다이얼로그 띄움.
      canPop: !_generatingIllustration,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_generatingIllustration) return;
        final shouldExit = await _confirmExitDuringGeneration();
        if (!shouldExit) return;
        if (!mounted) return;
        Navigator.of(context).pop();
      },
      child: BaseScaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('yyyy년 MM월 dd일', 'ko_KR').format(_diary.date),
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontFamily: 'GowunBatang'),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        // 우측 상단: "커뮤니티 게시" 글래스 텍스트 버튼 — 미공개/공개 상태에 따라
        // 라벨과 도트가 바뀐다. 그림 생성 중에는 비활성 (정합성 방지).
        actions: [
          CommunityShareSection(
            diary: _diary,
            disabled: _generatingIllustration,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 그림 일기 — 영역은 항상 유지. 그림이 없으면 placeholder + 지금 생성 버튼.
            _DiaryImage(
              diary: _diary,
              onUpdate: _updateDiary,
              onGeneratingChanged: (b) =>
                  setState(() => _generatingIllustration = b),
            ),
            const SizedBox(height: 24),

            // 2. 일기 보기
            _paperCard(_diary),
            const SizedBox(height: 20),

            // 3. AI 댓글 (감정 요약 위로 이동)
            _AiCommentCard(comment: _diary.aiComment),
            const SizedBox(height: 20),

            // 4. 오늘의 감정 & 해석 요약
            TodaySummaryCard(diary: _diary),
            const SizedBox(height: 20),

            // 4.5. 오늘의 음악 추천 — 신규 일기는 자동 생성, 기존 일기는 사용자가 추천 받기 버튼.
            MusicRecommendationSection(
              diary: _diary,
              onUpdate: _updateDiary,
            ),
            const SizedBox(height: 20),

            // 5. 내게 보내는 편지 섹션
            LetterSection(diary: _diary, onUpdate: _updateDiary),
            const SizedBox(height: 12),

            // 6. 사진 앱에 저장 — 옵션 토글 + 9:16 카드 캡쳐.
            //    그림 생성 중에는 캡쳐 무결성을 위해 비활성.
            _ShareToImageButton(
              disabled: _generatingIllustration,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        DiarySharePreviewScreen(diary: _diary),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 7. 대화 확인하기 버튼
            if (_diary.callId != null)
              _ActionButton(
                title: '대화 확인하기',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CallRecordScreen(callId: _diary.callId!),
                    ),
                  );
                },
              ),

            // 7. 일기 삭제 — 빨간 파스텔 글래스 톤. 그림 생성 중에는 비활성
            //    (편지/분석이 함께 사라지면 사용자가 혼란).
            const SizedBox(height: 20),
            _DeleteDiaryButton(
              deleting: _deleting,
              disabled: _generatingIllustration,
              onTap: _confirmDelete,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }
}

/// 그림일기 영역.
/// - URL 있음: 이미지 표시
/// - URL 없음: "통화 중에 생성되지 않았어요 — 지금 생성하기" placeholder
/// - 생성 중: 카드 안에서 인라인 진행 표시 (30~60초). 부모에게 [onGeneratingChanged]로 알려서
///   PopScope로 뒤로가기 차단 + 경고 다이얼로그 표시할 수 있게 함.
/// - 실패: 에러 메시지 + 다시 시도
class _DiaryImage extends ConsumerStatefulWidget {
  final DiaryEntry diary;
  final Future<void> Function(DiaryEntry) onUpdate;
  final ValueChanged<bool>? onGeneratingChanged;

  const _DiaryImage({
    required this.diary,
    required this.onUpdate,
    this.onGeneratingChanged,
  });

  @override
  ConsumerState<_DiaryImage> createState() => _DiaryImageState();
}

class _DiaryImageState extends ConsumerState<_DiaryImage> {
  bool _generating = false;
  String? _error;

  static const _gold = Color(0xFFFFD700);

  void _setGenerating(bool v) {
    if (_generating == v) return;
    setState(() => _generating = v);
    widget.onGeneratingChanged?.call(v);
  }

  Future<void> _generate() async {
    if (_generating) return;

    // 1) 사용자에게 그림 스타일 먼저 선택받는다 — 취소 시 생성 진입 자체를 막음.
    final theme = await showIllustrationThemePicker(context);
    if (theme == null) return;
    if (!mounted) return;

    setState(() => _error = null);
    _setGenerating(true);
    try {
      final userId = ref.read(userIdProvider);
      if (userId == null) {
        throw Exception('로그인 정보가 없어 그림을 만들 수 없어요');
      }
      final imageUrl = await OpenAIService().generateIllustrationForDiary(
        diary: widget.diary,
        userId: userId,
        theme: theme,
      );
      // 위젯이 dispose된 뒤(사용자가 나가기 선택 후)에는 결과 폐기.
      if (!mounted) return;
      final updated = widget.diary.copyWith(imageUrls: [imageUrl]);
      await widget.onUpdate(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        _setGenerating(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.diary.imageUrls.isNotEmpty;
    if (hasImage && !_generating) {
      return _buildImage(widget.diary.imageUrls.first);
    }
    return _buildPlaceholder();
  }

  Widget _buildImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.network(
        url,
        width: double.infinity,
        height: 300,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      color: Colors.white.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text('그림일기를 불러오는 중...',
                      style:
                          TextStyle(color: Colors.white.withOpacity(0.7))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _gold.withOpacity(0.06),
            Colors.transparent,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: _generating
              ? _generatingView()
              : (_error != null ? _errorView() : _idleView()),
        ),
      ),
    );
  }

  Widget _idleView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _gold.withOpacity(0.18),
            border: Border.all(color: _gold.withOpacity(0.4)),
          ),
          child: const Icon(Icons.auto_awesome,
              color: _gold, size: 26),
        ),
        const SizedBox(height: 14),
        const Text(
          '오늘의 일기를 그림으로 남겨볼까요?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'GowunBatang',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '원하는 스타일을 골라 그림을 그릴 수 있어요',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 12,
            fontFamily: 'GowunBatang',
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _generate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _gold.withOpacity(0.55)),
              boxShadow: [
                BoxShadow(
                  color: _gold.withOpacity(0.2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.brush_outlined, color: _gold, size: 16),
                SizedBox(width: 6),
                Text(
                  '지금 생성하기',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'GowunBatang',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _generatingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withOpacity(0.12),
              ),
            ),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(_gold),
              ),
            ),
            const Icon(Icons.auto_awesome, color: _gold, size: 18),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          '그림일기를 그리고 있어요',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'GowunBatang',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '잠시만 기다려 주세요 (30~60초)',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
            fontFamily: 'GowunBatang',
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline,
                  color: Colors.white.withOpacity(0.55), size: 12),
              const SizedBox(width: 5),
              Text(
                '나가면 생성이 취소돼요',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'GowunBatang',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.redAccent.withOpacity(0.15),
            border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
          ),
          child: const Icon(Icons.error_outline,
              color: Colors.redAccent, size: 24),
        ),
        const SizedBox(height: 14),
        const Text(
          '그림 생성에 실패했어요',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'GowunBatang',
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '잠시 후 다시 시도해 주세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12,
              fontFamily: 'GowunBatang',
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _generate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _gold.withOpacity(0.45)),
            ),
            child: const Text(
              '다시 시도',
              style: TextStyle(
                color: _gold,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'GowunBatang',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 일기 본문 맨 아래에 위치하는 "삭제하기" 빨간 파스텔 글래스 버튼.
/// - [deleting] 중엔 본문 자리에 작은 스피너.
/// - [disabled] (예: 그림 생성 중) 일 땐 옅게 비활성.
class _DeleteDiaryButton extends StatelessWidget {
  final bool deleting;
  final bool disabled;
  final VoidCallback onTap;

  const _DeleteDiaryButton({
    required this.deleting,
    required this.disabled,
    required this.onTap,
  });

  static const _pastelRed = Color(0xFFE57373);

  @override
  Widget build(BuildContext context) {
    final isDisabled = disabled || deleting;
    return Opacity(
      opacity: isDisabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _pastelRed.withOpacity(0.10),
                border: Border.all(color: _pastelRed.withOpacity(0.42)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (deleting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(_pastelRed),
                      ),
                    )
                  else
                    const Icon(
                      IconsaxPlusLinear.trash,
                      color: _pastelRed,
                      size: 18,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    deleting ? '삭제하는 중' : '삭제하기',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _pastelRed,
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
    );
  }
}

/// 사진 앱 저장 진입 버튼 — 골드 글래스 톤으로 일반 _ActionButton 보다 한 단계 강조.
/// 일기 본문 확인 → 사진 저장 → (대화 확인) → 삭제 순서로 흐름이 이어지도록 위에 배치.
class _ShareToImageButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool disabled;

  const _ShareToImageButton({
    required this.onTap,
    required this.disabled,
  });

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _gold.withOpacity(0.12),
                border: Border.all(color: _gold.withOpacity(0.45)),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withOpacity(0.16),
                    blurRadius: 14,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    IconsaxPlusLinear.gallery_add,
                    color: _gold,
                    size: 17,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '사진으로 저장하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _gold,
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
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _ActionButton({required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.1),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 디어로그 댓글 카드 — 별 아이콘 아바타 + "디어로그" 닉네임 + 댓글 박스 형태.
/// 일기에 누군가 댓글을 단 듯한 인상.
class _AiCommentCard extends StatelessWidget {
  final String? comment;
  const _AiCommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    final body = (comment != null && comment!.trim().isNotEmpty)
        ? comment!
        : '디어로그가 글을 쓰다가 잠들어버렸어요..\n다음 일기에서 따뜻한 한 마디로 보답할게요!';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아바타: 별 아이콘 + 그라데이션 배경
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFA78BFA), Color(0xFF60A5FA)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA78BFA).withOpacity(0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '디어로그',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 14.5,
                    height: 1.65,
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

Widget _paperCard(DiaryEntry diary) {
  return Stack(
    children: [
      Positioned.fill(
        child:
            Image.asset('asset/image/diary_white_page.png', fit: BoxFit.fill),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(diary.title,
                style: const TextStyle(
                    fontSize: 18,
                    height: 1.6,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(diary.content,
                style: const TextStyle(
                    fontSize: 14.5, height: 1.6, color: Colors.black)),
          ],
        ),
      ),
    ],
  );
}
