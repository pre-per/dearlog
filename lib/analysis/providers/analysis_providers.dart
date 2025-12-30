import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../diary/providers/diary_providers.dart';
import '../../diary/models/diary_entry.dart';

enum AnalysisRange { daily, weekly, monthly }

final analysisRangeProvider =
StateProvider<AnalysisRange>((ref) => AnalysisRange.daily);

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _startOfWeek(DateTime d) {
  final weekday = d.weekday % 7; // Sun=0
  return DateTime(d.year, d.month, d.day)
      .subtract(Duration(days: weekday));
}

class TrendPoint {
  final DateTime date;
  final int moodScore; // 0~100 (없으면 50)
  final String emotionLabel; // DiaryEntry.emotion
  TrendPoint({
    required this.date,
    required this.moodScore,
    required this.emotionLabel,
  });
}

final trendPointsProvider = Provider<AsyncValue<List<TrendPoint>>>((ref) {
  final range = ref.watch(analysisRangeProvider);
  final base = ref.watch(diaryStreamProvider);

  return base.whenData((list) {
    if (list.isEmpty) return const <TrendPoint>[];

    final sorted = [...list]..sort((a, b) => a.date.compareTo(b.date));

    List<TrendPoint> result = [];

    if (range == AnalysisRange.daily) {
      final picked =
      sorted.length <= 4 ? sorted : sorted.sublist(sorted.length - 4);

      result = picked.map(_entryToPoint).toList();
    }

    else if (range == AnalysisRange.weekly) {
      final now = DateTime.now();

      // 최근 4주
      final List<TrendPoint> weeklyPoints = [];

      for (int i = 3; i >= 0; i--) {
        final refDate = now.subtract(Duration(days: i * 7));

        final weekStart = _startOfWeek(refDate);
        final weekEnd = weekStart.add(const Duration(days: 7));

        final entries = sorted.where((e) {
          final d = e.date;
          return !d.isBefore(weekStart) && d.isBefore(weekEnd);
        }).toList();

        if (entries.isEmpty) continue;

        // ✅ 최빈 감정
        final freq = <String, int>{};
        for (final e in entries) {
          freq[e.emotion] = (freq[e.emotion] ?? 0) + 1;
        }

        final topEmotion =
            freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

        weeklyPoints.add(
          TrendPoint(
            date: weekStart,        // 주의 기준 날짜
            emotionLabel: topEmotion,
            moodScore: 50,          // 의미 없음 (고정)
          ),
        );
      }

      return weeklyPoints;
    }

    else {
      // ✅ 월간: 최근 4개월
      final now = DateTime.now();

      // Map<yyyy-mm, List<DiaryEntry>>
      final buckets = <String, List<DiaryEntry>>{};

      for (final e in sorted) {
        final key = '${e.date.year}-${e.date.month}';
        buckets.putIfAbsent(key, () => []).add(e);
      }

      // 최근 4개월 key 만들기
      final keys = List.generate(4, (i) {
        final d = DateTime(now.year, now.month - i, 1);
        return '${d.year}-${d.month}';
      }).reversed.toList();

      for (final key in keys) {
        final entries = buckets[key];
        if (entries == null || entries.isEmpty) continue;

        final avgScore = (entries
            .map((e) => e.analysis?.moodScore ?? 50)
            .reduce((a, b) => a + b) /
            entries.length)
            .round();

        // 대표 감정: 가장 많이 나온 emotion
        final freq = <String, int>{};
        for (final e in entries) {
          freq[e.emotion] = (freq[e.emotion] ?? 0) + 1;
        }
        final topEmotion =
            freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

        final anyDate = entries.first.date;

        result.add(TrendPoint(
          date: DateTime(anyDate.year, anyDate.month, 1),
          moodScore: avgScore,
          emotionLabel: topEmotion,
        ));
      }
    }

    return result;
  });
});

TrendPoint _entryToPoint(DiaryEntry e) {
  return TrendPoint(
    date: e.date,
    moodScore: e.analysis?.moodScore ?? 50,
    emotionLabel: e.emotion,
  );
}


class EmotionDistItem {
  final String emotion;
  final int percent; // 0~100
  EmotionDistItem({required this.emotion, required this.percent});
}

/// 주간 기준 감정 분포 (DiaryEntry.emotion 빈도 -> 퍼센트)
final weeklyEmotionDistProvider = Provider<AsyncValue<List<EmotionDistItem>>>((ref) {
  final base = ref.watch(diaryStreamProvider);

  return base.whenData((list) {
    final now = DateTime.now();
    final start = _startOfDay(now).subtract(const Duration(days: 6));
    final end = _startOfDay(now).add(const Duration(days: 1));

    final weekly = list.where((e) {
      final d = e.date;
      return !d.isBefore(start) && d.isBefore(end);
    }).toList();

    if (weekly.isEmpty) return const <EmotionDistItem>[];

    final freq = <String, int>{};
    for (final e in weekly) {
      final key = e.emotion.trim().isEmpty ? '기타' : e.emotion.trim();
      freq[key] = (freq[key] ?? 0) + 1;
    }

    final total = weekly.length;
    final items = freq.entries.map((en) {
      final pct = ((en.value / total) * 100).round();
      return EmotionDistItem(emotion: en.key, percent: pct);
    }).toList();

    // 많이 나온 순
    items.sort((a, b) => b.percent.compareTo(a.percent));
    return items.take(5).toList();
  });
});

class KeywordInsight {
  final String keyword;
  final int count;
  final String example; // 대표 문장 1개
  KeywordInsight({
    required this.keyword,
    required this.count,
    required this.example,
  });
}

final weeklyKeywordInsightsProvider =
Provider<AsyncValue<List<KeywordInsight>>>((ref) {
  final base = ref.watch(diaryStreamProvider);

  return base.whenData((list) {
    final now = DateTime.now();
    final start = _startOfDay(now).subtract(const Duration(days: 6));
    final end = _startOfDay(now).add(const Duration(days: 1));

    final weekly = list.where((e) {
      final d = e.date;
      return !d.isBefore(start) && d.isBefore(end);
    }).toList();

    if (weekly.isEmpty) return const <KeywordInsight>[];

    final freq = <String, int>{};
    final examples = <String, String>{};

    for (final entry in weekly) {
      final keys = entry.analysis?.mainWords ?? const <String>[];
      final sentences = entry.content
          .split(RegExp(r'(?<=[\.\!\?\n])\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      for (final k in keys) {
        final kk = k.trim();
        if (kk.isEmpty) continue;
        freq[kk] = (freq[kk] ?? 0) + 1;

        // 대표 문장: 키워드가 포함된 문장 1개
        examples[kk] ??= sentences.firstWhere(
              (s) => s.contains(kk),
          orElse: () => sentences.isNotEmpty ? sentences.first : '',
        );
      }
    }

    if (freq.isEmpty) return const <KeywordInsight>[];

    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(3).map((e) {
      final ex = (examples[e.key] ?? '').trim();
      return KeywordInsight(
        keyword: e.key,
        count: e.value,
        example: ex.isEmpty ? '이번 주에 "${e.key}" 이야기가 자주 나왔어요.' : ex,
      );
    }).toList();
  });
});


List<String> _splitSentences(String text) {
  // 한국어 단순 문장 분리: ., !, ?, \n 기준
  return text
      .split(RegExp(r'(?<=[\.\!\?\n])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

class ExtremeDayInsight {
  final DiaryEntry best;
  final DiaryEntry worst;
  ExtremeDayInsight({required this.best, required this.worst});
}

final weeklyExtremeDaysProvider =
Provider<AsyncValue<ExtremeDayInsight?>>((ref) {
  final base = ref.watch(diaryStreamProvider);

  return base.whenData((list) {
    final now = DateTime.now();
    final start = _startOfDay(now).subtract(const Duration(days: 6));
    final end = _startOfDay(now).add(const Duration(days: 1));

    final weekly = list.where((e) {
      final d = e.date;
      return !d.isBefore(start) && d.isBefore(end);
    }).toList();

    if (weekly.isEmpty) return null;

    int scoreOf(DiaryEntry e) => e.analysis?.moodScore ?? 50;

    weekly.sort((a, b) => scoreOf(a).compareTo(scoreOf(b)));
    final worst = weekly.first;
    final best = weekly.last;

    return ExtremeDayInsight(best: best, worst: worst);
  });
});

class WeeklyStabilityInsight {
  final int volatility; // max-min
  final int negativeStreakMax;
  final int stablePositiveStreakMax;
  WeeklyStabilityInsight({
    required this.volatility,
    required this.negativeStreakMax,
    required this.stablePositiveStreakMax,
  });
}

final weeklyStabilityProvider =
Provider<AsyncValue<WeeklyStabilityInsight?>>((ref) {
  final base = ref.watch(diaryStreamProvider);

  return base.whenData((list) {
    final now = DateTime.now();
    final start = _startOfDay(now).subtract(const Duration(days: 6));
    final end = _startOfDay(now).add(const Duration(days: 1));

    final weekly = list.where((e) {
      final d = e.date;
      return !d.isBefore(start) && d.isBefore(end);
    }).toList();

    if (weekly.length < 2) return null;

    weekly.sort((a, b) => a.date.compareTo(b.date));

    int scoreOf(DiaryEntry e) => e.analysis?.moodScore ?? 50;
    final scores = weekly.map(scoreOf).toList();

    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final volatility = maxScore - minScore;

    // 감정 카테고리로 연속 구간 계산
    // 부정: 슬픔/외로움/우울/분노/짜증/답답함
    // 안정/긍정: 평온/안정/차분/행복/만족/감사/기쁨/설렘/즐거움
    bool isNegative(String emo) => const {
      '슬픔','외로움','우울','분노','짜증','답답함'
    }.contains(emo);

    bool isStablePositive(String emo) => const {
      '평온','안정','차분','행복','만족','감사','기쁨','설렘','즐거움'
    }.contains(emo);

    int negMax = 0, negCur = 0;
    int posMax = 0, posCur = 0;

    for (final e in weekly) {
      final emo = e.emotion.trim();

      if (isNegative(emo)) {
        negCur++;
      } else {
        negMax = negCur > negMax ? negCur : negMax;
        negCur = 0;
      }

      if (isStablePositive(emo)) {
        posCur++;
      } else {
        posMax = posCur > posMax ? posCur : posMax;
        posCur = 0;
      }
    }
    negMax = negCur > negMax ? negCur : negMax;
    posMax = posCur > posMax ? posCur : posMax;

    return WeeklyStabilityInsight(
      volatility: volatility,
      negativeStreakMax: negMax,
      stablePositiveStreakMax: posMax,
    );
  });
});

