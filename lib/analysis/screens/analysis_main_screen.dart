import 'package:dearlog/app.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: const [
            SizedBox(height: 8),
            MonthNavigator(),
            SizedBox(height: 14),
            StreakBadge(),
            SizedBox(height: 22),

            // ── AI 인사이트 ──
            // 이달의 회고(AIInsightCard) 아래에 NLP 인지 필터 카드.
            // NLP 카드는 선택된 달의 가장 최근 일기 1개를 기준으로 동작.
            SectionHeader(
              title: 'AI 인사이트',
              icon: Icons.auto_awesome,
            ),
            SizedBox(height: 10),
            AIInsightCard(),
            SizedBox(height: 12),
            MonthlyNLPInsightSection(),
            SizedBox(height: 24),
            DottedDivider(),
            SizedBox(height: 24),

            // ── 키워드와 흐름 ──
            SectionHeader(
              title: '키워드와 흐름',
              icon: Icons.timeline_rounded,
            ),
            SizedBox(height: 10),
            KeywordMapCard(),
            SizedBox(height: 12),
            MoodChartCard(),
            SizedBox(height: 24),
            DottedDivider(),
            SizedBox(height: 24),

            // ── 활동과 기분 ──
            SectionHeader(
              title: '활동과 기분',
              icon: Icons.insights_rounded,
            ),
            SizedBox(height: 10),
            KeywordImpactCard(),
            SizedBox(height: 12),
            BestWorstDayCards(),
            SizedBox(height: 12),
            WeekdayMoodCard(),
            SizedBox(height: 24),
            DottedDivider(),
            SizedBox(height: 24),

            // ── 한 달의 모양 ──
            SectionHeader(
              title: '한 달의 모양',
              icon: Icons.donut_small_rounded,
            ),
            SizedBox(height: 10),
            EmotionDonutCard(),
            SizedBox(height: 12),
            ResilienceCard(),
            SizedBox(height: 24),
            DottedDivider(),
            SizedBox(height: 24),

            // ── 비교 ──
            SectionHeader(
              title: '비교',
              icon: Icons.compare_arrows_rounded,
            ),
            SizedBox(height: 10),
            MonthComparisonCard(),
            SizedBox(height: 12),
            NewKeywordsCard(),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
