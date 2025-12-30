import 'package:dearlog/app.dart';

class EmotionReportSection extends ConsumerWidget {
  const EmotionReportSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SectionTitle('감정 리포트'),
        SizedBox(height: 14),
        EmotionTrendCard(),
        SizedBox(height: 14),
        EmotionDistributionCard(),
      ],
    );
  }
}
