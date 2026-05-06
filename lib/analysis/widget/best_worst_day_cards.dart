import 'package:dearlog/app.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 이번 달 베스트 데이 / 워스트 데이 두 카드를 가로로 나란히.
/// 탭하면 해당 일기 detail로 이동.
class BestWorstDayCards extends ConsumerWidget {
  const BestWorstDayCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(monthlyStatsProvider);

    return asyncStats.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        if (stats.bestDay == null && stats.worstDay == null) {
          return const SizedBox.shrink();
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _DayCard(
                  kind: _Kind.best,
                  diary: stats.bestDay,
                  onTap: () => _open(context, ref, stats.bestDay),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DayCard(
                  kind: _Kind.worst,
                  diary: stats.worstDay,
                  onTap: () => _open(context, ref, stats.worstDay),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _open(
      BuildContext context, WidgetRef ref, DiaryEntry? diary) async {
    if (diary == null) return;
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    try {
      // 최신 데이터 보장 위해 fetch 한 번 더.
      final fresh = await ref
              .read(diaryRepositoryProvider)
              .fetchDiaryById(userId, diary.id) ??
          diary;
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DiaryDetailScreen(diary: fresh)),
      );
    } catch (_) {}
  }
}

enum _Kind { best, worst }

class _DayCard extends StatelessWidget {
  final _Kind kind;
  final DiaryEntry? diary;
  final VoidCallback onTap;

  const _DayCard({
    required this.kind,
    required this.diary,
    required this.onTap,
  });

  Color get _accent => kind == _Kind.best
      ? const Color(0xFF4ADE80)
      : const Color(0xFFFF7B7B);

  String get _label => kind == _Kind.best ? '베스트' : '워스트';
  String get _emoji => kind == _Kind.best ? '🌟' : '🌧';

  @override
  Widget build(BuildContext context) {
    final d = diary;
    if (d == null) {
      return _placeholder();
    }

    final score = d.analysis?.moodScore ?? 0;
    final scoreLabel = '${score >= 0 ? '+' : ''}$score';
    final firstQuote = d.analysis?.evidence.isNotEmpty == true
        ? d.analysis!.evidence.first.quote
        : (d.title.isNotEmpty
            ? d.title
            : (d.content.length > 40
                ? '${d.content.substring(0, 40)}…'
                : d.content));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  _label,
                  style: TextStyle(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  scoreLabel,
                  style: TextStyle(
                    color: _accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('M월 d일', 'ko_KR').format(d.date),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFamily: 'GowunBatang',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              firstQuote,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 11.5,
                height: 1.5,
                fontFamily: 'GowunBatang',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_emoji $_label',
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '아직 데이터가 부족해요',
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
