import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_fortune.dart';
import '../providers/daily_fortune_providers.dart';

/// 유리병 탭 시 띄우는 오늘의 운세 카드. 글래스모피즘 + 별점 / 행운색 / 행운 아이템.
///
/// 표시 후 자동으로 [fortuneSeenProvider] 를 마킹해 다음 빌드부터는 홈
/// 화면에서 유리병이 사라진다.
class FortuneCardSheet extends ConsumerStatefulWidget {
  const FortuneCardSheet({super.key});

  /// 모달 형태로 띄우는 헬퍼 — 호출자는 이걸로만 띄우면 된다.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => const FortuneCardSheet(),
    );
  }

  @override
  ConsumerState<FortuneCardSheet> createState() => _FortuneCardSheetState();
}

class _FortuneCardSheetState extends ConsumerState<FortuneCardSheet> {
  bool _markedSeen = false;

  Future<void> _markSeenIfNeeded() async {
    if (_markedSeen) return;
    _markedSeen = true;
    await ref.read(fortuneSeenProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context) {
    final asyncFortune = ref.watch(dailyFortuneProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.18),
                    Colors.white.withOpacity(0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.30),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  asyncFortune.when(
                    loading: () => const _LoadingBody(),
                    error: (e, _) => _ErrorBody(
                      message: e is Exception ? e.toString() : '운세를 불러오지 못했어요.',
                      onRetry: () {
                        ref.invalidate(dailyFortuneProvider);
                      },
                    ),
                    data: (fortune) {
                      // build 직후 1회 마킹 — 같은 호출로 두 번 마킹되지 않게 _markedSeen 가드.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _markSeenIfNeeded();
                      });
                      return _FortuneBody(fortune: fortune);
                    },
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

class _FortuneBody extends StatelessWidget {
  final DailyFortune fortune;
  const _FortuneBody({required this.fortune});

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDateLabel(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFA78BFA), Color(0xFF60A5FA)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA78BFA).withOpacity(0.45),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '오늘의 운세',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Text(
            fortune.body,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              height: 1.65,
              fontFamily: 'GowunBatang',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _StatRow(label: '금전', score: fortune.money),
        const SizedBox(height: 8),
        _StatRow(label: '애정', score: fortune.love),
        const SizedBox(height: 8),
        _StatRow(label: '업무', score: fortune.work),
        const SizedBox(height: 8),
        _StatRow(label: '건강', score: fortune.health),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _LuckyChip(
                emoji: '🍀',
                label: fortune.luckyColor.isEmpty ? '-' : fortune.luckyColor,
                caption: '행운 색',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LuckyChip(
                emoji: '✨',
                label: fortune.luckyItem.isEmpty ? '-' : fortune.luckyItem,
                caption: '행운 아이템',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            alignment: Alignment.center,
            child: const Text(
              '닫기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateLabel(DateTime d) {
    return '${d.month}월 ${d.day}일의 운세';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int score;
  const _StatRow({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: List.generate(5, (i) {
            final filled = i < score;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 22,
                color: filled
                    ? const Color(0xFFFFD964)
                    : Colors.white.withOpacity(0.3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _LuckyChip extends StatelessWidget {
  final String emoji;
  final String label;
  final String caption;
  const _LuckyChip({
    required this.emoji,
    required this.label,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caption,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(Color(0xFFFFD700)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '오늘의 운세를 꺼내는 중이에요…',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: Colors.white.withOpacity(0.6),
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            '운세를 불러오지 못했어요',
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD964).withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD964).withOpacity(0.42),
                ),
              ),
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  color: Color(0xFFFFD964),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
