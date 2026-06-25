import 'package:dearlog/app.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diariesAsync = ref.watch(diaryStreamProvider);
    final hasAnyDiary =
        diariesAsync.maybeWhen(data: (list) => list.isNotEmpty, orElse: () => true);

    // 일기가 한 건도 없으면 무거운 카드 10+ 개를 그리지 않고 빈 상태만 노출.
    // (각 카드가 내부적으로 빈 데이터 처리를 하더라도 시각적으로 placeholder 가
    //  연속으로 보이는 게 첫 사용자에게 좋지 않음.)
    if (!hasAnyDiary) {
      return BaseScaffold(
        body: const SafeArea(child: _AnalysisEmptyView()),
      );
    }

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

            // ── 디어로그 인사이트 ──
            // 이달의 회고(AIInsightCard) 아래에 NLP 인지 필터 카드.
            // NLP 카드는 선택된 달의 가장 최근 일기 1개를 기준으로 동작.
            SectionHeader(
              title: '디어로그 인사이트',
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

class _AnalysisEmptyView extends ConsumerWidget {
  const _AnalysisEmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_rounded,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              '분석할 일기가 아직 없어요',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'GowunBatang',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '통화로 첫 일기를 남기면\n감정 분석과 인사이트를 보여드릴게요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 13,
                height: 1.6,
                fontFamily: 'GowunBatang',
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () =>
                  ref.read(MainIndexProvider.notifier).state = 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.6),
                  ),
                ),
                child: const Text(
                  '홈으로 가서 통화 시작하기',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'GowunBatang',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
