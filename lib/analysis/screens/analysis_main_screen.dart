import 'package:dearlog/app.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseScaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                TodaySummaryCard(),
                SizedBox(height: 20),
                AnalysisRangeTabs(),
                SizedBox(height: 24),
                EmotionReportSection(),
                SizedBox(height: 32),
                DeepInsightSection(),
                SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
