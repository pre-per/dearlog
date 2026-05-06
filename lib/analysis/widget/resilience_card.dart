import 'package:dearlog/app.dart';
import 'package:flutter/material.dart';

/// 감정 회복력 — 부정적인 날(<-30) 다음 평소 이상으로 돌아오기까지의 평균 일수.
class ResilienceCard extends ConsumerWidget {
  const ResilienceCard({super.key});

  static const _gold = Color(0xFFFFD700);
  static const _green = Color(0xFF4ADE80);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(monthlyStatsProvider);

    return GlassCard(
      child: asyncStats.when(
        loading: () => const SizedBox(height: 80),
        error: (_, __) => const SizedBox.shrink(),
        data: (stats) {
          final avg = stats.avgRecoveryDays;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up_rounded,
                      color: _gold, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '감정 회복력',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (avg == null) ...[
                Text(
                  '이 달엔 부정적인 날 뒤의 회복 패턴을 확인할 만큼\n데이터가 모이지 않았어요',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                    height: 1.55,
                    fontFamily: 'GowunBatang',
                  ),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '평균 ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontFamily: 'GowunBatang',
                      ),
                    ),
                    Text(
                      avg.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _green,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '일',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontFamily: 'GowunBatang',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '부정적인 날(-30 이하) 뒤 평소(0 이상)로 돌아오기까지\n걸린 평균 시간이에요',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    height: 1.55,
                    fontFamily: 'GowunBatang',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
