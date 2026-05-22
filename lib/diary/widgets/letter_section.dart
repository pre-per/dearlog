import 'dart:ui';

import 'package:dearlog/app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// ── 편지지 색상 팔레트 ──
const _paper = Color(0xFFFAF6EA);
const _paperDeep = Color(0xFFF1EAD3);
const _ink = Color(0xFF2A2A3A);
const _inkSoft = Color(0xFF55556A);
const _gold = Color(0xFFD4A24C);
const _goldSoft = Color(0xFFE8C68A);

/// 일기 detail 화면에 표시되는 "내게 쓰는 편지" 섹션.
///
/// - 편지 리스트를 편지지 풍 카드로 표시
/// - 새 편지 작성 버튼 → 바텀시트 에디터
/// - 보내기 시 단계 progress 다이얼로그 + 자동 3회 재시도 + 실패 시 재시도 다이얼로그
/// - kDebugMode에서 잠금 즉시 해제 / 잠금 기간 단축 토글 제공
class LetterSection extends ConsumerStatefulWidget {
  final DiaryEntry diary;
  final Future<void> Function(DiaryEntry) onUpdate;

  const LetterSection({
    super.key,
    required this.diary,
    required this.onUpdate,
  });

  @override
  ConsumerState<LetterSection> createState() => _LetterSectionState();
}

class _LetterSectionState extends ConsumerState<LetterSection> {
  final _uuid = const Uuid();
  final _scheduler = LetterScheduler();

  List<Letter> get _letters {
    final list = List<Letter>.from(widget.diary.letters);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _persistLetters(List<Letter> updated) async {
    await widget.onUpdate(widget.diary.copyWith(letters: updated));
  }

  /// Firestore 저장을 자동 3회 재시도 (300ms → 600ms → 1200ms backoff).
  Future<void> _saveWithRetry(Future<void> Function() op) async {
    Object? lastError;
    for (int i = 0; i < 3; i++) {
      try {
        await op();
        return;
      } catch (e) {
        lastError = e;
        if (i < 2) {
          await Future.delayed(Duration(milliseconds: 300 * (1 << i)));
        }
      }
    }
    throw lastError ?? Exception('저장 실패');
  }

  Future<void> _openEditor({Letter? existing}) async {
    final result = await showModalBottomSheet<_EditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LetterEditorSheet(initial: existing?.content ?? ''),
    );
    if (result == null) return;

    final letter = existing ??
        Letter(
          id: _uuid.v4(),
          content: '',
          createdAt: DateTime.now(),
        );

    final trimmed = result.content.trim();

    if (trimmed.isEmpty && result.action == _EditorAction.close) return;

    if (result.action == _EditorAction.close) {
      // 닫기 = 임시저장 (draft)
      final updatedLetter = letter.copyWith(content: trimmed);
      final list = _letters.where((l) => l.id != letter.id).toList()
        ..add(updatedLetter);
      try {
        await _saveWithRetry(() => _persistLetters(list));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('임시 저장에 실패했어요: $e')),
          );
        }
      }
      return;
    }

    if (result.action == _EditorAction.send) {
      if (trimmed.isEmpty) return;
      await _sendWithProgress(
        letter: letter,
        content: trimmed,
        lockDays: result.lockDays,
      );
    }
  }

  /// 보내기 — 단계별 progress 다이얼로그 + 자동 재시도 + 실패 시 재시도 다이얼로그.
  Future<void> _sendWithProgress({
    required Letter letter,
    required String content,
    required int lockDays,
  }) async {
    final stepNotifier = ValueNotifier<int>(0);

    Letter? sealedResult;

    while (sealedResult == null) {
      // 진행 다이얼로그 표시
      stepNotifier.value = 0;
      final dialogFuture = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SendProgressDialog(stepNotifier: stepNotifier),
      );

      try {
        // Step 1: 편지 봉하기 (sentAt + unlockAt 부여)
        await Future.delayed(const Duration(milliseconds: 350));
        final base = letter.copyWith(content: content);
        final sealed = _scheduler.seal(base, lockDays: lockDays);
        stepNotifier.value = 1;

        // Step 2: 일기에 저장 (Firestore, 자동 3회 재시도)
        await Future.delayed(const Duration(milliseconds: 200));
        final list = _letters.where((l) => l.id != letter.id).toList()
          ..add(sealed);
        await _saveWithRetry(() => _persistLetters(list));
        stepNotifier.value = 2;

        // Step 3: 알림 예약
        await Future.delayed(const Duration(milliseconds: 200));
        await _scheduler.schedule(sealed: sealed, diaryId: widget.diary.id);
        stepNotifier.value = 3;

        // 완료 잠시 보여주기
        await Future.delayed(const Duration(milliseconds: 600));

        // 다이얼로그 닫기
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        await dialogFuture; // 닫힘 대기
        sealedResult = sealed;
      } catch (e) {
        // 진행 다이얼로그 닫기
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        await dialogFuture;

        if (!mounted) return;
        // 재시도 다이얼로그 (글래스모피즘)
        final retry = await showGlassDialog<bool>(
          context: context,
          title: '편지를 보내지 못했어요',
          message: '잠시 문제가 생긴 것 같아요. 다시 시도할까요?',
          actions: const [
            GlassDialogAction(label: '취소', value: false),
            GlassDialogAction(label: '다시 시도', value: true, isPrimary: true),
          ],
        );
        if (retry != true) return;
        // while loop가 다시 시도
      }
    }

    // 성공 알림
    if (mounted) {
      final days = sealedResult.unlockAt!
          .difference(sealedResult.sentAt!)
          .inDays;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            days > 0
                ? '편지를 봉했어요. $days일 뒤 ${_fmtTime(sealedResult.unlockAt!)}에 도착해요.'
                : '편지를 봉했어요. 곧 도착할 거예요.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E1E2E),
        ),
      );
    }
  }

  Future<void> _deleteLetter(Letter letter) async {
    final ok = await showGlassDialog<bool>(
      context: context,
      title: '편지를 삭제할까요?',
      message: letter.isLocked
          ? '잠금된 편지가 사라지고 도착 알림도 취소돼요.'
          : '편지를 삭제하면 되돌릴 수 없어요.',
      actions: const [
        GlassDialogAction(label: '취소', value: false),
        GlassDialogAction(label: '삭제', value: true, isDestructive: true),
      ],
    );
    if (ok != true) return;

    await _scheduler.cancel(letter);
    final list = _letters.where((l) => l.id != letter.id).toList();
    try {
      await _saveWithRetry(() => _persistLetters(list));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제에 실패했어요: $e')),
        );
      }
    }
  }

  /// [DEBUG] 잠금된 편지의 unlockAt을 now로 바꿔 즉시 unlocked 상태로 전환.
  /// 알림은 취소 (이미 도착한 셈이므로).
  Future<void> _debugUnlock(Letter letter) async {
    if (!kDebugMode) return;
    await _scheduler.cancel(letter);
    final unlocked = letter.copyWith(unlockAt: DateTime.now());
    final list = _letters.map((l) => l.id == letter.id ? unlocked : l).toList();
    try {
      await _saveWithRetry(() => _persistLetters(list));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('[DEBUG] 잠금 해제됨'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF1E1E2E),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('[DEBUG] 해제 실패: $e')),
        );
      }
    }
  }

  Future<void> _showLetterContextMenu(Letter letter) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              if (kDebugMode && letter.isLocked)
                ListTile(
                  leading: const Icon(Icons.lock_open_rounded,
                      color: _goldSoft),
                  title: const Text('[DEBUG] 잠금 즉시 해제',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'unlockAt을 now로 변경 + 알림 취소',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(ctx, 'debug_unlock'),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                title: const Text('편지 삭제',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white60),
                title: const Text('취소',
                    style: TextStyle(color: Colors.white60)),
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == 'delete') {
      await _deleteLetter(letter);
    } else if (action == 'debug_unlock') {
      await _debugUnlock(letter);
    }
  }

  void _showUnlockedReader(Letter letter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LetterReaderSheet(letter: letter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final letters = _letters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
          child: Row(
            children: [
              const Icon(Icons.mail_outline_rounded,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '내게 쓰는 편지',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (kDebugMode) const _DebugFastModeToggle(),
              if (kDebugMode) const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openEditor(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('새 편지',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (letters.isEmpty)
          _EmptyHint(onTap: () => _openEditor())
        else
          ...letters.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _LetterCard(
                  letter: l,
                  onTap: () {
                    if (l.isDraft) {
                      _openEditor(existing: l);
                    } else if (l.isUnlocked) {
                      _showUnlockedReader(l);
                    }
                  },
                  onLongPress: () => _showLetterContextMenu(l),
                ),
              )),
      ],
    );
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final period = h < 12 ? '오전' : '오후';
    final hh = h % 12 == 0 ? 12 : h % 12;
    return '$period $hh시';
  }
}

// ─────────────────────────────────────────────────
// 편지 카드
// ─────────────────────────────────────────────────

class _LetterCard extends StatelessWidget {
  final Letter letter;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LetterCard({
    required this.letter,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: _PaperContainer(
        child: _stateContent(),
      ),
    );
  }

  Widget _stateContent() {
    if (letter.isDraft) return _draftBody();
    if (letter.isLocked) return _lockedBody();
    return _unlockedBody();
  }

  Widget _draftBody() {
    final preview = letter.content.trim().isEmpty
        ? '내용을 작성해주세요'
        : letter.content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.edit_outlined, color: _gold, size: 16),
            const SizedBox(width: 6),
            const Text('작성 중인 편지',
                style: TextStyle(
                    color: _gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2)),
            const Spacer(),
            Text(
              DateFormat('yyyy.M.d').format(letter.createdAt),
              style: const TextStyle(
                  color: _inkSoft, fontSize: 11, fontFamily: 'GowunBatang'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: _gold.withOpacity(0.22)),
        const SizedBox(height: 10),
        Text(
          preview,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            height: 1.7,
            fontFamily: 'GowunBatang',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.touch_app_outlined,
                color: _inkSoft.withOpacity(0.6), size: 13),
            const SizedBox(width: 4),
            Text(
              '탭해서 이어 쓰기 · 길게 눌러 메뉴',
              style: TextStyle(
                  color: _inkSoft.withOpacity(0.7),
                  fontSize: 11,
                  fontFamily: 'GowunBatang'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _lockedBody() {
    final daysLeft = letter.daysUntilUnlock;
    final unlockDate = letter.unlockAt!;
    final isToday = daysLeft == 0;
    final unlockText = isToday
        ? '오늘 ${_fmtTimeShort(unlockDate)} 도착'
        : 'D-$daysLeft  ${DateFormat('M월 d일').format(unlockDate)} 도착';

    return SizedBox(
      height: 156,
      child: Stack(
        children: [
          // 흐릿한 본문 미리보기
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    letter.content,
                    maxLines: 6,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      color: _ink.withOpacity(0.5),
                      fontSize: 13,
                      height: 1.6,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 잠금 오버레이
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _paper.withOpacity(0.55),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _gold,
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withOpacity(0.3),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.lock_outline_rounded,
                        color: _paper, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    unlockText,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '잠금이 풀리면 알림으로 알려드릴게요',
                    style: TextStyle(
                      color: _inkSoft.withOpacity(0.75),
                      fontSize: 11.5,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '작성 ${DateFormat('yyyy.M.d').format(letter.createdAt)}',
                    style: TextStyle(
                      color: _inkSoft.withOpacity(0.55),
                      fontSize: 10.5,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unlockedBody() {
    final preview = letter.content.trim();
    final days = letter.daysSinceSent;
    final badgeText = days == 0 ? '오늘 도착' : '$days일 전에 보낸 편지';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.mark_email_read_outlined, color: _gold, size: 16),
            const SizedBox(width: 6),
            Text(badgeText,
                style: const TextStyle(
                    color: _gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2)),
            const Spacer(),
            Text(
              '${DateFormat('M.d').format(letter.createdAt)} → ${DateFormat('M.d').format(letter.unlockAt ?? letter.sentAt!)}',
              style: const TextStyle(
                  color: _inkSoft, fontSize: 11, fontFamily: 'GowunBatang'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: _gold.withOpacity(0.22)),
        const SizedBox(height: 12),
        Text(
          preview,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            height: 1.8,
            fontFamily: 'GowunBatang',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '탭해서 전문 보기',
          style: TextStyle(
              color: _inkSoft.withOpacity(0.7),
              fontSize: 11,
              fontFamily: 'GowunBatang'),
        ),
      ],
    );
  }

  static String _fmtTimeShort(DateTime dt) {
    final h = dt.hour;
    final period = h < 12 ? '오전' : '오후';
    final hh = h % 12 == 0 ? 12 : h % 12;
    return '$period $hh시';
  }
}

/// 편지지 풍 컨테이너 — 크림 배경 + 그림자 + 좌측 금색 리본 + 미세한 줄무늬.
class _PaperContainer extends StatelessWidget {
  final Widget child;
  const _PaperContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.32),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // 종이 배경
            Positioned.fill(
              child: CustomPaint(painter: _PaperPainter()),
            ),
            // 좌측 금색 리본
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_goldSoft, _gold, _goldSoft],
                  ),
                ),
              ),
            ),
            // 본문
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// 크림 배경 + 미세한 가로 줄 (편지지 느낌).
class _PaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 베이스 크림
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _paper,
    );
    // 우상단 살짝 톤다운 그라데이션 (오래된 종이 느낌)
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.topRight,
          radius: 1.4,
          colors: [Color(0x14C0A064), Colors.transparent],
        ).createShader(Offset.zero & size),
    );
    // 가로 줄
    final linePaint = Paint()
      ..color = _gold.withOpacity(0.10)
      ..strokeWidth = 0.7;
    const spacing = 26.0;
    const startY = 22.0;
    for (double y = startY; y < size.height - 6; y += spacing) {
      canvas.drawLine(Offset(14, y), Offset(size.width - 14, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────
// 날짜 선택 칩 — 에디터 헤더에서 "30일 뒤 도착" 으로 보이는 작은 chip.
// ─────────────────────────────────────────────────

class _DaysChip extends StatelessWidget {
  final int days;
  final VoidCallback onTap;
  const _DaysChip({required this.days, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _gold.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _gold.withOpacity(0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, color: _gold, size: 13),
            const SizedBox(width: 5),
            Text(
              '$days일 뒤 도착',
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'GowunBatang',
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.expand_more_rounded,
                color: _ink.withOpacity(0.55), size: 14),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 빈 상태 힌트
// ─────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _PaperContainer(
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_calendar_outlined,
                  color: _gold, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '미래의 나에게 편지를 보내보세요',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '원하는 날 뒤 알림으로 도착해요.',
                    style: TextStyle(
                      color: _inkSoft,
                      fontSize: 12,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _inkSoft, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 디버그 토글 — 잠금 기간 0~30초 모드
// ─────────────────────────────────────────────────

class _DebugFastModeToggle extends StatefulWidget {
  const _DebugFastModeToggle();

  @override
  State<_DebugFastModeToggle> createState() => _DebugFastModeToggleState();
}

class _DebugFastModeToggleState extends State<_DebugFastModeToggle> {
  @override
  Widget build(BuildContext context) {
    final on = LetterScheduler.debugFastMode;
    return GestureDetector(
      onTap: () {
        setState(() {
          LetterScheduler.debugFastMode = !on;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(on
                ? '[DEBUG] 잠금 기간을 정상(30~40일)으로 복귀'
                : '[DEBUG] 잠금 기간을 0~30초로 단축'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF1E1E2E),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: on ? Colors.redAccent.withOpacity(0.85) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: on ? Colors.redAccent : Colors.white.withOpacity(0.3)),
        ),
        child: Text(
          on ? 'DEBUG: 30s' : 'DEBUG',
          style: TextStyle(
              color: on ? Colors.white : Colors.white.withOpacity(0.55),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 진행 다이얼로그 (3단계 + 금색 + 편지 아이콘)
// ─────────────────────────────────────────────────

class _SendProgressDialog extends StatelessWidget {
  final ValueNotifier<int> stepNotifier;
  const _SendProgressDialog({required this.stepNotifier});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: _paper,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '편지를 보내는 중',
                style: TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'GowunBatang',
                ),
              ),
              const SizedBox(height: 4),
              ValueListenableBuilder<int>(
                valueListenable: stepNotifier,
                builder: (context, completed, _) {
                  final msg = completed >= 3
                      ? '편지가 잘 봉해졌어요'
                      : '잠시만 기다려 주세요';
                  return Text(
                    msg,
                    style: TextStyle(
                      color: _inkSoft.withOpacity(0.8),
                      fontSize: 12,
                      fontFamily: 'GowunBatang',
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              ValueListenableBuilder<int>(
                valueListenable: stepNotifier,
                builder: (context, completed, _) =>
                    _StepBar(completed: completed),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int completed; // 0..3
  const _StepBar({required this.completed});

  // 띄어쓰기 위치에서 줄바꿈 — 카드가 좁아도 깔끔하게 2줄로 떨어짐.
  static const _labels = ['잉크\n굳히기', '편지지\n봉인', '보내기\n완료'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 원 + 사이 선
        SizedBox(
          height: 44,
          child: Row(
            children: [
              _StepCircle(index: 0, completed: completed),
              Expanded(child: _StepLine(filled: completed >= 1)),
              _StepCircle(index: 1, completed: completed),
              Expanded(child: _StepLine(filled: completed >= 2)),
              _StepCircle(index: 2, completed: completed),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 라벨 — 각 원 아래 정렬
        Row(
          children: [
            SizedBox(
                width: 44,
                child: Text(_labels[0],
                    textAlign: TextAlign.center,
                    style: _labelStyle(completed >= 0))),
            const Expanded(child: SizedBox.shrink()),
            SizedBox(
                width: 44,
                child: Text(_labels[1],
                    textAlign: TextAlign.center,
                    style: _labelStyle(completed >= 1))),
            const Expanded(child: SizedBox.shrink()),
            SizedBox(
                width: 44,
                child: Text(_labels[2],
                    textAlign: TextAlign.center,
                    style: _labelStyle(completed >= 2))),
          ],
        ),
      ],
    );
  }

  TextStyle _labelStyle(bool active) {
    return TextStyle(
      color: active ? _ink : _inkSoft.withOpacity(0.5),
      fontSize: 11,
      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
      fontFamily: 'GowunBatang',
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int index;
  final int completed;
  const _StepCircle({required this.index, required this.completed});

  @override
  Widget build(BuildContext context) {
    final isDone = index < completed;
    final isActive = index == completed && completed < 3;
    final isAllDone = completed >= 3;
    final filled = isDone || isActive || isAllDone;

    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: isActive ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOut,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? _gold : _paperDeep,
              border: Border.all(
                color: filled ? _gold : _gold.withOpacity(0.35),
                width: filled ? 0 : 1.4,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: _gold.withOpacity(0.45),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: isDone
                    ? const Icon(Icons.check_rounded,
                        key: ValueKey('check'),
                        color: _paper,
                        size: 18)
                    : Icon(
                        Icons.mail_outline_rounded,
                        key: ValueKey(filled ? 'mail_active' : 'mail_idle'),
                        color: filled ? _paper : _gold.withOpacity(0.55),
                        size: 17,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool filled;
  const _StepLine({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: filled
                ? const [_goldSoft, _gold]
                : [
                    _gold.withOpacity(0.18),
                    _gold.withOpacity(0.18),
                  ],
          ),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 에디터 시트 (편지지 풍)
// ─────────────────────────────────────────────────

enum _EditorAction { close, send }

class _EditorResult {
  final _EditorAction action;
  final String content;

  /// 보내기 시 적용할 잠금 일수. close 액션일 때는 의미 없음(기본값 유지).
  final int lockDays;

  _EditorResult(this.action, this.content,
      {this.lockDays = LetterScheduler.defaultLockDays});
}

class _LetterEditorSheet extends StatefulWidget {
  final String initial;
  const _LetterEditorSheet({required this.initial});

  @override
  State<_LetterEditorSheet> createState() => _LetterEditorSheetState();
}

class _LetterEditorSheetState extends State<_LetterEditorSheet> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  /// 사용자가 고른 잠금 일수. 기본 30일.
  int _lockDays = LetterScheduler.defaultLockDays;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.pop(
      context,
      _EditorResult(_EditorAction.close, _controller.text,
          lockDays: _lockDays),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('편지 내용을 적어주세요'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    Navigator.pop(
      context,
      _EditorResult(_EditorAction.send, _controller.text, lockDays: _lockDays),
    );
  }

  /// 며칠 뒤 도착할지 픽커 — CupertinoPicker 휠. 1~180일 범위.
  Future<void> _pickLockDays() async {
    int tempDays = _lockDays;
    final picked = await showCupertinoModalPopup<int>(
      context: context,
      builder: (_) => Container(
        height: 280,
        color: const Color(0xFF1C1C2E),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context, tempDays),
                    child: const Text('완료',
                        style: TextStyle(color: _gold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                magnification: 1.1,
                squeeze: 1.2,
                useMagnifier: true,
                itemExtent: 40,
                scrollController: FixedExtentScrollController(
                  initialItem: _lockDays - LetterScheduler.minLockDays,
                ),
                onSelectedItemChanged: (i) {
                  tempDays = LetterScheduler.minLockDays + i;
                },
                children: List<Widget>.generate(
                  LetterScheduler.maxLockDays -
                      LetterScheduler.minLockDays +
                      1,
                  (i) {
                    final d = LetterScheduler.minLockDays + i;
                    return Center(
                      child: Text(
                        '$d일 뒤',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (picked != null && picked != _lockDays) {
      setState(() => _lockDays = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Stack(
            children: [
              // 편지지 배경
              Positioned.fill(child: CustomPaint(painter: _PaperPainter())),
              // 좌측 금색 리본
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_goldSoft, _gold, _goldSoft],
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: _ink.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _close,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close,
                                  color: _inkSoft, size: 22),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '미래의 나에게',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'GowunBatang',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _DaysChip(
                                  days: _lockDays,
                                  onTap: _pickLockDays,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _send,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _gold,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                      color: _gold.withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2)),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.send_rounded,
                                      color: _paper, size: 14),
                                  SizedBox(width: 6),
                                  Text('보내기',
                                      style: TextStyle(
                                          color: _paper,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'GowunBatang')),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                          height: 1, color: _gold.withOpacity(0.2)),
                      const SizedBox(height: 6),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          autofocus: true,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          cursorColor: _gold,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            height: 1.95,
                            fontFamily: 'GowunBatang',
                          ),
                          decoration: const InputDecoration(
                            hintText: '오늘 하루 수고한 나에게…\n\n한 달 뒤의 내가 받게 될 편지예요.',
                            hintStyle: TextStyle(
                              color: _inkSoft,
                              height: 1.95,
                              fontFamily: 'GowunBatang',
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 리더 시트 (편지지 풍)
// ─────────────────────────────────────────────────

class _LetterReaderSheet extends StatelessWidget {
  final Letter letter;
  const _LetterReaderSheet({required this.letter});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _PaperPainter())),
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_goldSoft, _gold, _goldSoft],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _ink.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.mark_email_read_outlined,
                            color: _gold, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          letter.daysSinceSent == 0
                              ? '오늘 도착한 편지'
                              : '${letter.daysSinceSent}일 전에 보낸 편지',
                          style: const TextStyle(
                              color: _gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'GowunBatang'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '작성 ${DateFormat('yyyy년 M월 d일').format(letter.createdAt)}',
                      style: const TextStyle(
                          color: _inkSoft,
                          fontSize: 12,
                          fontFamily: 'GowunBatang'),
                    ),
                    const SizedBox(height: 14),
                    Container(height: 1, color: _gold.withOpacity(0.22)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          letter.content,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            height: 2.0,
                            fontFamily: 'GowunBatang',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
