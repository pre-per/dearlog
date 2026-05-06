import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../diary/providers/diary_providers.dart';
import '../../diary/models/diary_analysis.dart';
import '../../diary/models/diary_entry.dart';

class SelectedMonth {
  final int year;
  final int month;
  const SelectedMonth(this.year, this.month);

  factory SelectedMonth.now() {
    final n = DateTime.now();
    return SelectedMonth(n.year, n.month);
  }

  DateTime get start => DateTime(year, month, 1);
  DateTime get end => DateTime(year, month + 1, 1);

  bool get isCurrent {
    final n = DateTime.now();
    return year == n.year && month == n.month;
  }

  SelectedMonth get previous {
    final d = DateTime(year, month - 1, 1);
    return SelectedMonth(d.year, d.month);
  }

  SelectedMonth get next {
    final d = DateTime(year, month + 1, 1);
    return SelectedMonth(d.year, d.month);
  }

  String get label => '$year년 $month월';

  @override
  bool operator ==(Object other) =>
      other is SelectedMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

final selectedMonthProvider =
    StateProvider<SelectedMonth>((ref) => SelectedMonth.now());

/// 선택된 달 내에서 가장 최근에 작성된 일기.
/// 해당 달에 일기가 없으면 null.
/// 분석 페이지의 "오늘의 마음 인지 필터" 카드가 이 일기를 기준으로 동작.
final latestDiaryInSelectedMonthProvider = Provider<DiaryEntry?>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final state = ref.watch(diaryStreamProvider);

  return state.when(
    data: (list) {
      final inMonth = list
          .where((e) =>
              !e.date.isBefore(month.start) && e.date.isBefore(month.end))
          .toList();
      if (inMonth.isEmpty) return null;
      inMonth.sort((a, b) => b.date.compareTo(a.date));
      return inMonth.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

final currentMonthExistingKeywordsProvider = Provider<List<String>>((ref) {
  final list = ref.watch(diaryStreamProvider).asData?.value;
  if (list == null || list.isEmpty) return const [];

  final n = DateTime.now();
  final start = DateTime(n.year, n.month, 1);
  final end = DateTime(n.year, n.month + 1, 1);

  final words = <String>{};
  for (final d in list) {
    if (d.date.isBefore(start) || !d.date.isBefore(end)) continue;
    final keywords = d.analysis?.keywords ?? const <KeywordEntry>[];
    for (final k in keywords) {
      final w = k.word.trim();
      if (w.isNotEmpty) words.add(w);
    }
  }
  return words.toList();
});

class DiaryRef {
  final String diaryId;
  final DateTime date;
  final String quote;

  DiaryRef({
    required this.diaryId,
    required this.date,
    required this.quote,
  });
}

class KeywordMapItem {
  final String word;
  final KeywordCategory category;
  final String emotion;
  final Map<String, int> emotionCounts;
  final int count;
  final List<DiaryRef> sources;

  KeywordMapItem({
    required this.word,
    required this.category,
    required this.emotion,
    required this.emotionCounts,
    required this.count,
    required this.sources,
  });
}

const int _maxKeywordsOnMap = 15;

final monthlyKeywordMapProvider =
    Provider<AsyncValue<List<KeywordMapItem>>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final base = ref.watch(diaryStreamProvider);

  return base.whenData((list) {
    final inMonth = list.where((e) {
      return !e.date.isBefore(month.start) && e.date.isBefore(month.end);
    }).toList();

    if (inMonth.isEmpty) return const <KeywordMapItem>[];

    final emotionFreq = <String, Map<String, int>>{};
    final category = <String, KeywordCategory>{};
    final count = <String, int>{};
    final sources = <String, List<DiaryRef>>{};

    for (final entry in inMonth) {
      final analysis = entry.analysis;
      if (analysis == null) continue;
      final evidences = analysis.evidence;

      for (final kw in analysis.keywords) {
        final w = kw.word.trim();
        if (w.isEmpty) continue;

        count[w] = (count[w] ?? 0) + 1;
        category[w] ??= kw.category;

        final eFreq = emotionFreq.putIfAbsent(w, () => <String, int>{});
        if (kw.emotion.isNotEmpty) {
          eFreq[kw.emotion] = (eFreq[kw.emotion] ?? 0) + 1;
        }

        String quote = '';
        for (final ev in evidences) {
          if (ev.quote.contains(w)) {
            quote = ev.quote;
            break;
          }
        }
        if (quote.isEmpty && evidences.isNotEmpty) {
          quote = evidences.first.quote;
        }
        if (quote.isEmpty) {
          if (entry.title.isNotEmpty) {
            quote = entry.title;
          } else {
            final c = entry.content.trim();
            quote = c.length > 60 ? '${c.substring(0, 60)}…' : c;
          }
        }

        sources.putIfAbsent(w, () => []).add(DiaryRef(
              diaryId: entry.id,
              date: entry.date,
              quote: quote,
            ));
      }
    }

    final items = count.entries.map((e) {
      final word = e.key;
      final eFreq = emotionFreq[word] ?? const <String, int>{};
      String dominantEmotion = '';
      if (eFreq.isNotEmpty) {
        final sorted = eFreq.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        dominantEmotion = sorted.first.key;
      }
      final src = sources[word] ?? const <DiaryRef>[];
      final sortedSrc = [...src]..sort((a, b) => b.date.compareTo(a.date));
      return KeywordMapItem(
        word: word,
        category: category[word] ?? KeywordCategory.noun,
        emotion: dominantEmotion,
        emotionCounts: Map<String, int>.from(eFreq),
        count: e.value,
        sources: sortedSrc,
      );
    }).toList()
      ..sort((a, b) {
        final c = b.count.compareTo(a.count);
        if (c != 0) return c;
        final ad = a.sources.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : a.sources.first.date;
        final bd = b.sources.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : b.sources.first.date;
        final d = bd.compareTo(ad);
        if (d != 0) return d;
        return a.word.compareTo(b.word);
      });

    return items.take(_maxKeywordsOnMap).toList();
  });
});

// ─────────────────────────────────────────────────
// Monthly mood series — 한 달 기분 흐름 그래프용
// ─────────────────────────────────────────────────

/// 한 일기 항목의 기분 데이터 포인트.
class MoodPoint {
  final String diaryId;
  final DateTime date;
  /// -100 ~ +100. analysis.moodScore. analysis 없으면 0.
  final int score;
  /// 그 일기의 대표 명사 키워드 (annotation 표시용). 없으면 null.
  final String? topNoun;

  MoodPoint({
    required this.diaryId,
    required this.date,
    required this.score,
    required this.topNoun,
  });
}

/// 그래프 위에 말풍선으로 강조할 극점 인덱스.
class MoodExtreme {
  final int index;
  /// 진폭 (인접 평균 대비 차이의 절대값). 표시 우선순위 정렬에 사용.
  final double swing;
  /// true면 봉우리(neighbor 대비 위), false면 골짜기(아래).
  final bool isPeak;

  MoodExtreme({
    required this.index,
    required this.swing,
    required this.isPeak,
  });
}

class MoodSeriesData {
  final List<MoodPoint> points;
  final List<MoodExtreme> extremes;

  const MoodSeriesData({required this.points, required this.extremes});

  bool get isEmpty => points.isEmpty;
}

const double _extremeThreshold = 25.0;
const int _maxExtremes = 4;

/// 선택된 달의 기분 흐름 시계열.
/// 일기 없는 날은 점이 없음 (선이 양옆 점들을 그대로 이어줌).
final monthlyMoodSeriesProvider =
    Provider<AsyncValue<MoodSeriesData>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final base = ref.watch(diaryStreamProvider);

  return base.whenData((list) {
    final inMonth = list
        .where((e) =>
            !e.date.isBefore(month.start) && e.date.isBefore(month.end))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (inMonth.isEmpty) {
      return const MoodSeriesData(points: [], extremes: []);
    }

    final points = inMonth.map((e) => _buildPoint(e)).toList();
    final extremes = _findExtremes(points);
    return MoodSeriesData(points: points, extremes: extremes);
  });
});

MoodPoint _buildPoint(DiaryEntry e) {
  final analysis = e.analysis;
  final score = analysis?.moodScore ?? 0;

  String? topNoun;
  if (analysis != null) {
    for (final k in analysis.keywords) {
      if (k.category == KeywordCategory.noun && k.word.trim().isNotEmpty) {
        topNoun = k.word.trim();
        break;
      }
    }
  }
  return MoodPoint(
    diaryId: e.id,
    date: e.date,
    score: score,
    topNoun: topNoun,
  );
}

/// 로컬 극점(주변보다 두드러진 봉우리/골짜기)을 진폭 큰 순으로 [_maxExtremes]개.
/// - 점 1개: 점이 임계값 이상으로 0과 떨어져 있으면 단독 극점으로 표시.
/// - 점 2개 이상: 양옆 점과 비교해 진폭 [_extremeThreshold] 이상이면 후보.
List<MoodExtreme> _findExtremes(List<MoodPoint> series) {
  if (series.isEmpty) return const [];
  if (series.length == 1) {
    final s = series[0].score;
    if (s.abs() >= _extremeThreshold) {
      return [MoodExtreme(index: 0, swing: s.abs().toDouble(), isPeak: s > 0)];
    }
    return const [];
  }

  final candidates = <MoodExtreme>[];
  for (int i = 0; i < series.length; i++) {
    final score = series[i].score;
    final left = i > 0 ? series[i - 1].score : null;
    final right = i < series.length - 1 ? series[i + 1].score : null;

    final isLocalMax =
        (left == null || score > left) && (right == null || score > right);
    final isLocalMin =
        (left == null || score < left) && (right == null || score < right);
    if (!isLocalMax && !isLocalMin) continue;

    double swing = 0;
    if (left != null) swing = math.max(swing, (score - left).abs().toDouble());
    if (right != null) swing = math.max(swing, (score - right).abs().toDouble());

    if (swing >= _extremeThreshold) {
      candidates
          .add(MoodExtreme(index: i, swing: swing, isPeak: isLocalMax));
    }
  }

  candidates.sort((a, b) => b.swing.compareTo(a.swing));
  return candidates.take(_maxExtremes).toList()
    ..sort((a, b) => a.index.compareTo(b.index));
}

