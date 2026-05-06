import 'package:dearlog/app.dart';
import 'package:flutter/material.dart';

/// 분석 페이지의 "오늘의 마음 인지 필터" 섹션.
///
/// 선택된 달 안에서 가장 최근 일기 1개를 기준으로 NLP 인지 필터를 보여준다.
/// 해당 달에 일기가 없으면 빈 상태 카드를 노출.
/// 실제 카드/생성 로직은 [NLPInsightCard]에 위임하고, 여기서는
/// "어떤 일기를 보여줄지"만 결정한다.
class MonthlyNLPInsightSection extends ConsumerWidget {
  const MonthlyNLPInsightSection({super.key});

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = ref.watch(latestDiaryInSelectedMonthProvider);

    if (diary == null) {
      return const _EmptyView();
    }

    return NLPInsightCard(
      diary: diary,
      onUpdate: (updated) async {
        final userId = ref.read(userIdProvider);
        if (userId == null) return;
        await ref.read(diaryRepositoryProvider).saveDiary(userId, updated);
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MonthlyNLPInsightSection._gold.withOpacity(0.15),
                  border: Border.all(
                      color: MonthlyNLPInsightSection._gold.withOpacity(0.4)),
                ),
                child: const Center(
                  child: Text('🧠', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의 마음 인지 필터',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NLP 신경언어프로그래밍 기반 심리 분석',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '이 달엔 아직 일기가 없어요.\n일기를 한 편 남기면 인지 필터를 비춰드릴게요.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
