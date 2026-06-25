import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/providers.dart';
import '../../diary/providers/diary_providers.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../../user/providers/user_stats_providers.dart';
import '../models/my_planet.dart';
import '../models/planet_catalog.dart';
import '../repository/planet_repository.dart';

/// 행성/Nova 카탈로그(v2, 하드코딩 — 좌표/이름 개발 정의). 동기 제공.
final planetCatalogProvider = Provider<PlanetCatalog>((ref) {
  return PlanetCatalog.v2();
});

final planetRepositoryProvider = Provider<PlanetRepository>((ref) {
  return PlanetRepository(firestore: ref.watch(firestoreProvider));
});

/// Firestore 에 저장된 내 행성(없으면 null). 내부용.
final _storedPlanetProvider = StreamProvider<MyPlanet?>((ref) {
  final uid = ref.watch(userIdProvider);
  if (uid == null || uid.isEmpty) {
    return const Stream<MyPlanet?>.empty();
  }
  return ref.watch(planetRepositoryProvider).watchMyPlanet(uid);
});

/// 화면에서 쓰는 '유효한' 내 행성. 저장된 게 없으면 닉네임 기반 기본값으로 폴백
/// 하므로 항상 non-null — 위젯이 로딩/널 분기를 신경 쓰지 않아도 된다.
final myPlanetProvider = Provider<MyPlanet>((ref) {
  final stored = ref.watch(_storedPlanetProvider).valueOrNull;
  if (stored != null) return stored;
  final nickname = ref.watch(userProvider).valueOrNull?.profile.nickname ?? '';
  return MyPlanet.initial(nickname);
});

/// 사용자가 아직 행성을 저장한 적이 없는지(첫 진입 안내용).
final hasStoredPlanetProvider = Provider<bool>((ref) {
  return ref.watch(_storedPlanetProvider).valueOrNull != null;
});

/// 카드/상세의 '최근 감정 요약'. 최근 30일 일기의 대표 감정 분포 상위 3개.
/// 최근 30일에 기록이 없으면 전체 기록으로 폴백한다.
final recentEmotionSummaryProvider = Provider<List<EmotionSlice>>((ref) {
  final entries = ref.watch(diaryStreamProvider).valueOrNull;
  if (entries == null || entries.isEmpty) return const [];

  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  final recent = entries.where((e) => e.date.isAfter(cutoff)).toList();
  final source = recent.isNotEmpty ? recent : entries;

  final counts = <String, int>{};
  for (final d in source) {
    final emotions = d.analysis?.emotions ?? const [];
    String? top;
    if (emotions.isNotEmpty) {
      top = emotions.first.name.trim();
    } else if (d.emotion.trim().isNotEmpty) {
      top = d.emotion.trim();
    }
    if (top != null && top.isNotEmpty) {
      counts[top] = (counts[top] ?? 0) + 1;
    }
  }

  final total = counts.values.fold<int>(0, (a, b) => a + b);
  if (total == 0) return const [];

  final sorted =
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  return sorted
      .take(3)
      .map(
        (e) =>
            EmotionSlice(label: e.key, ratio: e.value / total, count: e.value),
      )
      .toList(growable: false);
});

/// 별조각 수(표시용). 1차에서는 경제 없이 기존 통계로 파생한다.
/// 규칙(asset_manifest StarPieceRules 기반): 일기 1일 +10, 최장 연속 1일당 +5.
final starPieceCountProvider = Provider<int>((ref) {
  final stats = ref.watch(myUserStatsProvider).valueOrNull;
  if (stats == null) return 0;
  return stats.diaryCount * 10 + stats.longestStreak * 5;
});

/// 최근 감정 요약 1조각.
class EmotionSlice {
  final String label;

  /// 0~1 비율.
  final double ratio;
  final int count;

  const EmotionSlice({
    required this.label,
    required this.ratio,
    required this.count,
  });

  /// 표시용 정수 퍼센트.
  int get percent => (ratio * 100).round();
}
