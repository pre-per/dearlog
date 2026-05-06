import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diary/models/diary_analysis.dart';
import '../../diary/models/diary_entry.dart';
import '../../diary/providers/diary_providers.dart';
import 'analysis_providers.dart';

// ─────────────────────────────────────────────────
// 통계 데이터 클래스들
// ─────────────────────────────────────────────────

class KeywordImpact {
  final String word;
  final double avgMood;
  final int count;
  KeywordImpact({
    required this.word,
    required this.avgMood,
    required this.count,
  });
}

class WeekdayMood {
  /// 1=월 ~ 7=일 (DateTime.weekday).
  final Map<int, double> averages;
  final Map<int, int> counts;
  WeekdayMood({required this.averages, required this.counts});
}

class MonthComparison {
  final double currentAvg;
  final double prevAvg;
  final List<String> appeared;
  final List<String> disappeared;
  MonthComparison({
    required this.currentAvg,
    required this.prevAvg,
    required this.appeared,
    required this.disappeared,
  });

  double get delta => currentAvg - prevAvg;
}

class StreakInfo {
  final int current;
  final int longest;
  StreakInfo({required this.current, required this.longest});
}

/// 분석 페이지에서 계산되는 모든 파생 통계 묶음.
class MonthlyStats {
  final List<KeywordImpact> topImpacts;     // 긍정 영향 상위
  final List<KeywordImpact> bottomImpacts;  // 부정 영향 상위
  final DiaryEntry? bestDay;
  final DiaryEntry? worstDay;
  final WeekdayMood weekday;
  final Map<String, int> emotionDistribution;
  final double? avgRecoveryDays;
  final List<String> newKeywords;
  final MonthComparison? comparison;
  final int diaryCount;

  const MonthlyStats({
    required this.topImpacts,
    required this.bottomImpacts,
    required this.bestDay,
    required this.worstDay,
    required this.weekday,
    required this.emotionDistribution,
    required this.avgRecoveryDays,
    required this.newKeywords,
    required this.comparison,
    required this.diaryCount,
  });

  bool get isEmpty => diaryCount == 0;
}

// ─────────────────────────────────────────────────
// 헬퍼 함수들
// ─────────────────────────────────────────────────

bool _isInMonth(DateTime d, SelectedMonth m) =>
    !d.isBefore(m.start) && d.isBefore(m.end);

double _avg(Iterable<num> xs) {
  if (xs.isEmpty) return 0;
  final sum = xs.fold<double>(0, (a, b) => a + b.toDouble());
  return sum / xs.length;
}

Set<String> _nounsOf(DiaryEntry d) {
  final out = <String>{};
  for (final k in d.analysis?.keywords ?? const <KeywordEntry>[]) {
    if (k.category == KeywordCategory.noun) {
      final w = k.word.trim();
      if (w.isNotEmpty) out.add(w);
    }
  }
  return out;
}

// ─────────────────────────────────────────────────
// 활동-감정 상관관계 (Top 3 / Bottom 3)
// ─────────────────────────────────────────────────

({List<KeywordImpact> top, List<KeywordImpact> bottom}) _computeImpacts(
    List<DiaryEntry> inMonth) {
  // word → list of mood scores
  final bucket = <String, List<int>>{};
  for (final d in inMonth) {
    final mood = d.analysis?.moodScore;
    if (mood == null) continue;
    for (final w in _nounsOf(d)) {
      bucket.putIfAbsent(w, () => []).add(mood);
    }
  }

  // 2회 이상 등장한 단어만 후보
  final candidates = bucket.entries
      .where((e) => e.value.length >= 2)
      .map((e) => KeywordImpact(
            word: e.key,
            avgMood: _avg(e.value),
            count: e.value.length,
          ))
      .toList();

  // 양수 점수 → 긍정 영향, 음수 점수 → 부정 영향
  final positive = candidates.where((k) => k.avgMood > 0).toList()
    ..sort((a, b) => b.avgMood.compareTo(a.avgMood));
  final negative = candidates.where((k) => k.avgMood < 0).toList()
    ..sort((a, b) => a.avgMood.compareTo(b.avgMood));

  return (
    top: positive.take(3).toList(),
    bottom: negative.take(3).toList(),
  );
}

// ─────────────────────────────────────────────────
// 베스트/워스트 데이
// ─────────────────────────────────────────────────

({DiaryEntry? best, DiaryEntry? worst}) _findExtremeDays(
    List<DiaryEntry> inMonth) {
  DiaryEntry? best;
  DiaryEntry? worst;
  int bestScore = -101;
  int worstScore = 101;
  for (final d in inMonth) {
    final s = d.analysis?.moodScore;
    if (s == null) continue;
    if (s > bestScore) {
      bestScore = s;
      best = d;
    }
    if (s < worstScore) {
      worstScore = s;
      worst = d;
    }
  }
  // 같은 일기가 best/worst 양쪽 차지하지 않도록 (점수 동일하면 worst 비움)
  if (best != null && worst != null && best.id == worst.id) {
    worst = null;
  }
  return (best: best, worst: worst);
}

// ─────────────────────────────────────────────────
// 요일별 기분
// ─────────────────────────────────────────────────

WeekdayMood _computeWeekday(List<DiaryEntry> inMonth) {
  final sums = <int, int>{};
  final counts = <int, int>{};
  for (final d in inMonth) {
    final s = d.analysis?.moodScore;
    if (s == null) continue;
    final wd = d.date.weekday; // 1..7
    sums[wd] = (sums[wd] ?? 0) + s;
    counts[wd] = (counts[wd] ?? 0) + 1;
  }
  final avg = <int, double>{};
  for (int wd = 1; wd <= 7; wd++) {
    final c = counts[wd] ?? 0;
    avg[wd] = c == 0 ? 0 : (sums[wd]! / c);
  }
  return WeekdayMood(averages: avg, counts: counts);
}

// ─────────────────────────────────────────────────
// 감정 분포 — 일별 top emotion 카운트
// ─────────────────────────────────────────────────

Map<String, int> _computeEmotionDistribution(List<DiaryEntry> inMonth) {
  final counts = <String, int>{};
  for (final d in inMonth) {
    final emotions = d.analysis?.emotions ?? const <EmotionScore>[];
    if (emotions.isEmpty) {
      // analysis 없으면 diary.emotion 라벨 사용
      final e = d.emotion.trim();
      if (e.isNotEmpty) counts[e] = (counts[e] ?? 0) + 1;
      continue;
    }
    final top = emotions.first.name.trim();
    if (top.isNotEmpty) counts[top] = (counts[top] ?? 0) + 1;
  }
  return counts;
}

// ─────────────────────────────────────────────────
// 회복력 — 부정(<-30)에서 0 이상 회복까지 평균 일수
// ─────────────────────────────────────────────────

double? _computeRecovery(List<DiaryEntry> all, SelectedMonth month) {
  // 해당 달 + 전후 한 달까지 봐서 회복 거리 계산.
  // (월 마지막 날에 부정 → 다음 달에 회복하는 케이스 포함)
  final from = month.start.subtract(const Duration(days: 30));
  final to = month.end.add(const Duration(days: 60));
  final relevant = all
      .where((d) => !d.date.isBefore(from) && d.date.isBefore(to))
      .where((d) => d.analysis != null)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  final gaps = <int>[];
  for (int i = 0; i < relevant.length; i++) {
    final di = relevant[i];
    // 이번 달 안에서 시작된 부정 일기만 카운트
    if (!_isInMonth(di.date, month)) continue;
    if (di.analysis!.moodScore >= -30) continue;

    for (int j = i + 1; j < relevant.length; j++) {
      if (relevant[j].analysis!.moodScore >= 0) {
        final days = relevant[j].date.difference(di.date).inDays;
        if (days > 0) gaps.add(days);
        break;
      }
    }
  }

  if (gaps.isEmpty) return null;
  return _avg(gaps);
}

// ─────────────────────────────────────────────────
// 새로 등장한 키워드 — 이번 달엔 있는데 직전 6개월엔 없던 단어
// ─────────────────────────────────────────────────

List<String> _computeNewKeywords(List<DiaryEntry> all, SelectedMonth month) {
  final lookbackStart = DateTime(month.year, month.month - 6, 1);

  final thisMonth = all.where((d) => _isInMonth(d.date, month));
  final past = all.where((d) =>
      !d.date.isBefore(lookbackStart) && d.date.isBefore(month.start));

  final thisSet = <String>{};
  for (final d in thisMonth) {
    thisSet.addAll(_nounsOf(d));
  }
  final pastSet = <String>{};
  for (final d in past) {
    pastSet.addAll(_nounsOf(d));
  }

  return thisSet.difference(pastSet).toList()..sort();
}

// ─────────────────────────────────────────────────
// 이전 달 대비 변화
// ─────────────────────────────────────────────────

MonthComparison? _computeComparison(
    List<DiaryEntry> all, SelectedMonth month) {
  final prev = month.previous;

  final inThis =
      all.where((d) => _isInMonth(d.date, month) && d.analysis != null);
  final inPrev =
      all.where((d) => _isInMonth(d.date, prev) && d.analysis != null);

  if (inPrev.isEmpty || inThis.isEmpty) return null;

  final currAvg = _avg(inThis.map((d) => d.analysis!.moodScore));
  final prevAvg = _avg(inPrev.map((d) => d.analysis!.moodScore));

  final currNouns = <String>{};
  for (final d in inThis) {
    currNouns.addAll(_nounsOf(d));
  }
  final prevNouns = <String>{};
  for (final d in inPrev) {
    prevNouns.addAll(_nounsOf(d));
  }

  final appeared = currNouns.difference(prevNouns).toList()..sort();
  final disappeared = prevNouns.difference(currNouns).toList()..sort();

  return MonthComparison(
    currentAvg: currAvg,
    prevAvg: prevAvg,
    appeared: appeared.take(5).toList(),
    disappeared: disappeared.take(5).toList(),
  );
}

// ─────────────────────────────────────────────────
// Streak — 전체 일기 기준
// ─────────────────────────────────────────────────

StreakInfo _computeStreak(List<DiaryEntry> all) {
  if (all.isEmpty) return StreakInfo(current: 0, longest: 0);

  final daySet = <DateTime>{};
  for (final d in all) {
    daySet.add(DateTime(d.date.year, d.date.month, d.date.day));
  }
  final sorted = daySet.toList()..sort();

  // 최장 streak
  int longest = 1;
  int run = 1;
  for (int i = 1; i < sorted.length; i++) {
    final diff = sorted[i].difference(sorted[i - 1]).inDays;
    if (diff == 1) {
      run++;
      if (run > longest) longest = run;
    } else if (diff > 1) {
      run = 1;
    }
  }

  // 현재 streak — 마지막 날짜가 오늘이거나 어제라면 카운트
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final lastDay = sorted.last;
  final daysSinceLast = today.difference(lastDay).inDays;

  int current = 0;
  if (daysSinceLast <= 1) {
    current = 1;
    for (int i = sorted.length - 2; i >= 0; i--) {
      final diff = sorted[i + 1].difference(sorted[i]).inDays;
      if (diff == 1) {
        current++;
      } else {
        break;
      }
    }
  }

  return StreakInfo(current: current, longest: longest);
}

// ─────────────────────────────────────────────────
// Combined provider
// ─────────────────────────────────────────────────

/// 한 번에 전체 통계를 계산해서 묶어 반환.
/// 일기 한 번 순회로 끝나도록 효율 신경 씀.
final monthlyStatsProvider =
    Provider<AsyncValue<MonthlyStats>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final base = ref.watch(diaryStreamProvider);

  return base.whenData((all) {
    final inMonth = all.where((d) => _isInMonth(d.date, month)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final impacts = _computeImpacts(inMonth);
    final extremes = _findExtremeDays(inMonth);
    final weekday = _computeWeekday(inMonth);
    final distribution = _computeEmotionDistribution(inMonth);
    final recovery = _computeRecovery(all, month);
    final newKeywords = _computeNewKeywords(all, month);
    final comparison = _computeComparison(all, month);

    return MonthlyStats(
      topImpacts: impacts.top,
      bottomImpacts: impacts.bottom,
      bestDay: extremes.best,
      worstDay: extremes.worst,
      weekday: weekday,
      emotionDistribution: distribution,
      avgRecoveryDays: recovery,
      newKeywords: newKeywords,
      comparison: comparison,
      diaryCount: inMonth.length,
    );
  });
});

/// Streak — 전체 일기 기준이라 selectedMonth와 독립.
final diaryStreakProvider = Provider<StreakInfo>((ref) {
  final base = ref.watch(diaryStreamProvider);
  return base.maybeWhen(
    data: (all) => _computeStreak(all),
    orElse: () => StreakInfo(current: 0, longest: 0),
  );
});
