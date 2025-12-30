import 'package:dearlog/app.dart';

class DeepInsightSection extends ConsumerWidget {
  const DeepInsightSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(analysisRangeProvider);

    // 월간은 MVP에서 간단 안내만
    if (range == AnalysisRange.monthly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionTitle('이번 달 인사이트'),
          SizedBox(height: 14),
          GlassCard(
            child: Text(
              '월간 인사이트는 기록이 더 쌓이면 더 정확해져요.\n우선 주간 탭에서 패턴을 확인해보세요.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      );
    }

    // 일간/주간 공용이지만, “의미 있는 데이터”는 주간에서 더 강하니
    // 일간에서도 같은 카드들을 보여주되, 문구를 “최근 7일 기준”이라고 명시.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('이번 주 인사이트'),
        const SizedBox(height: 14),

        // 1) 키워드 Top3 + 대표 문장
        _WeeklyKeywordsCard(),

        const SizedBox(height: 12),

        // 2) 최고/최저의 날
        _ExtremeDaysCard(),

        const SizedBox(height: 12),

        // 3) 변동성 + 연속 구간
        _StabilityCard(),

        const SizedBox(height: 12),

        // 4) 행동 추천 (analysis.recommendations 기반)
        _RecentRecommendationsSection()
      ],
    );
  }
}

class _WeeklyKeywordsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyKeywordInsightsProvider);

    return GlassCard(
      child: async.when(
        data: (items) {
          if (items.isEmpty) {
            return const Text(
              '이번 주 기록이 아직 부족해요. 일기를 조금만 더 써보면 키워드를 찾아줄게요.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '자주 등장한 키워드',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    items.map((k) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Text(
                          '${k.keyword} (${k.count})',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 12),

              // 대표 문장: 1위 키워드 기준으로 1개만 보여주기
              const Text(
                '대표 문장',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                '“${items.first.example}”',
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
        loading:
            () => const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
        error:
            (e, _) =>
                Text('오류: $e', style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}

class _ExtremeDaysCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyExtremeDaysProvider);

    return GlassCard(
      child: async.when(
        data: (insight) {
          if (insight == null) {
            return const Text(
              '이번 주 데이터가 부족해요.',
              style: TextStyle(color: Colors.white70),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tappableRow(
                title: '가장 안정적이었던 날',
                context: context,
                entry: insight.best,
              ),
              const SizedBox(height: 14),
              tappableRow(
                title: '가장 힘들었던 날',
                context: context,
                entry: insight.worst,
              ),
            ],
          );
        },
        loading:
            () => const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
        error:
            (e, _) =>
                Text('오류: $e', style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}

class _StabilityCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyStabilityProvider);

    return GlassCard(
      child: async.when(
        data: (s) {
          if (s == null) {
            return const Text(
              '이번 주 데이터가 더 필요해요.',
              style: TextStyle(color: Colors.white70),
            );
          }

          String volatilityLabel(int v) {
            if (v <= 15) return '안정';
            if (v <= 30) return '보통';
            return '큼';
          }

          final vLabel = volatilityLabel(s.volatility);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '숫자로 보는 흐름',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),

              Text(
                '감정 기복: ${s.volatility}점 ($vLabel)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),

              Text(
                '부정 감정 최대 연속: ${s.negativeStreakMax}일',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 6),

              Text(
                '안정/긍정 최대 연속: ${s.stablePositiveStreakMax}일',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 10),

              const Text(
                '※ 최근 7일 일기 기준으로 계산돼요.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          );
        },
        loading:
            () => const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
        error:
            (e, _) =>
                Text('오류: $e', style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}

void _openDiary(BuildContext context, DiaryEntry entry) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => DiaryDetailScreen(diary: entry)));
}

Widget tappableRow({
  required BuildContext context,
  required String title,
  required DiaryEntry entry,
}) {
  final date = entry.date;
  final emotion = entry.emotion;
  final score = entry.analysis?.moodScore ?? 50;
  final content = entry.content;

  final label = '${date.month}/${date.day}';
  final example =
      content.trim().isEmpty
          ? ''
          : (content.length > 60 ? '${content.substring(0, 60)}…' : content);

  return InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () => _openDiary(context, entry),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$label · $emotion · $score점',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (example.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '“$example”',
              style: const TextStyle(color: Colors.white, height: 1.35),
            ),
          ],
        ],
      ),
    ),
  );
}

class _RecentRecommendationsSection extends ConsumerWidget {
  const _RecentRecommendationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = ref.watch(latestDiaryProvider);

    // 최신 일기 없음
    if (diary == null || diary.analysis == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionTitle('오늘을 위한 제안'),
          SizedBox(height: 12),
          GlassCard(
            child: Text(
              '아직 분석할 일기가 없어요.\n오늘의 기록을 남겨보세요.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      );
    }

    final recs = diary.analysis!.recommendations;

    if (recs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionTitle('오늘을 위한 제안'),
          SizedBox(height: 12),
          GlassCard(
            child: Text(
              '오늘은 특별한 추천이 없어요.\n지금의 리듬을 유지해보세요.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('오늘을 위한 작은 제안'),
        const SizedBox(height: 12),

        // 추천 카드 리스트
        ...List.generate(
          recs.length,
              (i) => Padding(
            padding: EdgeInsets.only(bottom: i == recs.length - 1 ? 0 : 10),
            child: _RecommendationTile(
              rec: recs[i],
              index: i,
            ),
          ),
        ),

        const SizedBox(height: 6),
        Text(
          '※ 최근 작성한 일기 1개를 기준으로 추천했어요.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}


class _RecommendationTile extends StatelessWidget {
  final Recommendation rec;
  final int index;

  const _RecommendationTile({
    required this.rec,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final r = rec;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 번호 + 제목 + 분 뱃지
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _MinuteBadge(minutes: r.minutes),
            ],
          ),

          const SizedBox(height: 10),

          _StepsPreview(steps: r.steps),
        ],
      ),
    );
  }
}

class _MinuteBadge extends StatelessWidget {
  final int minutes;
  const _MinuteBadge({required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$minutes분',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StepsPreview extends StatelessWidget {
  final List<String> steps;
  const _StepsPreview({required this.steps});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const Text(
        '추천 단계가 비어있어요.',
        style: TextStyle(color: Colors.white70),
      );
    }

    final preview = steps.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < preview.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == preview.length - 1 ? 0 : 6),
            child: Text(
              '• ${preview[i]}',
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
      ],
    );
  }
}