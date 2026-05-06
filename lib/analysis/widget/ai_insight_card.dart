import 'package:dearlog/app.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// AI가 생성한 한 달 회고 + 반복 패턴을 한 카드에 묶어 표시.
/// - 캐시 있음: 본문 + 패턴 + "다시 생성하기" 버튼
/// - 캐시 없음 (현재 달 자동 생성 중): 로딩 표시
/// - 캐시 없음 (과거 달): "회고 만들기" 버튼
/// - 에러: 에러 메시지 + 재시도
class AIInsightCard extends ConsumerWidget {
  const AIInsightCard({super.key});

  static const _gold = Color(0xFFFFD700);
  static const _goldSoft = Color(0xFFD4A24C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(monthlyInsightProvider);
    final notifier = ref.read(monthlyInsightProvider.notifier);
    final month = ref.watch(selectedMonthProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: _gold, size: 18),
              const SizedBox(width: 6),
              Text(
                '이 달의 회고',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (state.insight != null)
                _RefreshButton(
                  onTap: state.isLoading ? null : notifier.regenerate,
                  loading: state.isLoading,
                ),
            ],
          ),
          const SizedBox(height: 14),
          _body(state, notifier, month),
        ],
      ),
    );
  }

  Widget _body(
    MonthlyInsightState state,
    MonthlyInsightNotifier notifier,
    SelectedMonth month,
  ) {
    if (state.isLoading && state.insight == null) {
      return const _LoadingView();
    }
    if (state.error != null && state.insight == null) {
      return _ErrorView(
          error: state.error!, onRetry: notifier.regenerate);
    }
    if (state.insight == null) {
      return _EmptyView(month: month, onGenerate: notifier.regenerate);
    }
    return _LoadedView(insight: state.insight!);
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AIInsightCard._gold),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '이 달의 흐름을 정리하고 있어요',
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final SelectedMonth month;
  final VoidCallback onGenerate;
  const _EmptyView({required this.month, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          month.isCurrent
              ? '이번 달은 아직 회고가 없어요'
              : '${month.label} 회고가 아직 없어요',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '일기 흐름을 바탕으로 만들어줘요',
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        _PrimaryButton(label: '회고 만들기', onTap: onGenerate),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '회고를 불러오지 못했어요',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          error,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        _PrimaryButton(label: '다시 시도', onTap: onRetry),
      ],
    );
  }
}

class _LoadedView extends StatelessWidget {
  final MonthlyInsight insight;
  const _LoadedView({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          insight.summary.isEmpty ? '이 달에 대한 회고가 비어 있어요.' : insight.summary,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.7,
            fontFamily: 'GowunBatang',
          ),
        ),
        if (insight.patterns.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AIInsightCard._goldSoft.withOpacity(0.4),
                  AIInsightCard._goldSoft.withOpacity(0.0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...insight.patterns.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PatternRow(pattern: p),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          '${DateFormat('yyyy.M.d HH:mm').format(insight.generatedAt)}  ·  '
          '${insight.diaryCount}개 일기 기반',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _PatternRow extends StatelessWidget {
  final DiscoveredPattern pattern;
  const _PatternRow({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AIInsightCard._gold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pattern.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'GowunBatang',
                ),
              ),
              if (pattern.body.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  pattern.body,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    height: 1.55,
                    fontFamily: 'GowunBatang',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AIInsightCard._gold.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AIInsightCard._gold.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome,
                color: AIInsightCard._gold, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AIInsightCard._gold,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'GowunBatang',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  const _RefreshButton({required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      valueColor:
                          AlwaysStoppedAnimation(AIInsightCard._gold),
                    ),
                  )
                : Icon(
                    Icons.refresh,
                    size: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
            const SizedBox(width: 4),
            Text(
              loading ? '생성 중' : '다시 생성',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
