import 'package:dearlog/app.dart';

class TodaySummaryCard extends ConsumerWidget {
  const TodaySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(latestDiaryProvider);
    final analysis = today?.analysis;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 감정 상태 요약',
            style: TextStyle(color: Color(0xefffffff), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            analysis?.summary ?? '오늘의 감정을 분석 중이에요.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
