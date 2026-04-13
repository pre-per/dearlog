import 'package:dearlog/app.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = ref.watch(latestDiaryProvider);

    return BaseScaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (diary != null)
                  TodaySummaryCard(diary: diary)
                else
                  const GlassCard(child: Text('분석할 일기가 없어요.', style: TextStyle(color: Colors.white70))),
                const SizedBox(height: 20),
                const AnalysisRangeTabs(),
                const SizedBox(height: 24),
                const EmotionReportSection(),
                const SizedBox(height: 32),
                const DeepInsightSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
