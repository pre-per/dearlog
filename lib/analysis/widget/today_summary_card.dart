import 'package:dearlog/app.dart';

class TodaySummaryCard extends ConsumerWidget {
  const TodaySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = ref.watch(latestDiaryProvider);

    if (diary == null || diary.analysis == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          GlassCard(
            child: Column(
              children: [
                Text(
                  '오늘의 감정 상태 요약',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 10),
                Text(
                  '아직 분석할 일기가 없어요.\n오늘의 기록을 남겨보세요.',
                  style: TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final analysis = diary.analysis!;
    final topEmotion = analysis.emotions.isNotEmpty ? analysis.emotions.first : null;
    final quote = analysis.evidence.isNotEmpty ? analysis.evidence.first : null;

    final mood = analysis.moodScore;
    final moodLabel = mood >= 70
        ? '비교적 안정'
        : (mood >= 45 ? '약간 힘듦' : '많이 힘듦');

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "오늘의 감정 상태 요약",
            style: const TextStyle(
              color: Colors.white60,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          // 한 줄 요약(공감 톤)
          Text(
            analysis.summary,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // 오늘 상태 요약
          Row(
            children: [
              _SmallChip(text: '기분 점수 $mood점 · $moodLabel'),
              const SizedBox(width: 8),
              if (topEmotion != null)
                _SmallChip(text: '주요 감정: ${topEmotion.name} (${topEmotion.score})'),
            ],
          ),

          if (quote != null) ...[
            const SizedBox(height: 10),
            Text(
              '근거',
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '“${quote.quote}”',
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
            const SizedBox(height: 6),
            Text(
              quote.why,
              style: const TextStyle(color: Colors.white60, height: 1.35, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}


class _SmallChip extends StatelessWidget {
  final String text;
  const _SmallChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}