import 'package:dearlog/app.dart';

class TodaySummaryCard extends StatelessWidget {
  final DiaryEntry diary;
  const TodaySummaryCard({super.key, required this.diary});

  @override
  Widget build(BuildContext context) {
    final analysis = diary.analysis;

    if (analysis == null) {
      return const GlassCard(
        child: Text(
          '아직 분석할 일기가 없어요.\n오늘의 기록을 남겨보세요.',
          style: TextStyle(color: Colors.white70, height: 1.35),
        ),
      );
    }

    final topEmotion = analysis.emotions.isNotEmpty ? analysis.emotions.first : null;
    final quote = analysis.evidence.isNotEmpty ? analysis.evidence.first : null;
    final mood = analysis.moodScore;
    final moodLabel = mood >= 70 ? '비교적 안정' : (mood >= 45 ? '약간 힘듦' : '많이 힘듦');

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "오늘의 감정 상태 요약",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            analysis.summary,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // 감정 요약
          Row(
            children: [
              _SmallChip(text: '기분 점수 $mood점 · $moodLabel'),
              if (topEmotion != null) ...[
                const SizedBox(width: 8),
                _SmallChip(text: '주요 감정: ${topEmotion.name} (${topEmotion.score})'),
              ],
            ],
          ),

          // 근거 (이전 내용 복구)
          if (quote != null) ...[
            const SizedBox(height: 16),
            Text(
              '근거',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '“${quote.quote}”',
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
            const SizedBox(height: 6),
            Text(
              quote.why,
              style: const TextStyle(
                color: Colors.white60,
                height: 1.35,
                fontSize: 12,
              ),
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
