import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/di/providers.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../../shared_ui/utils/search_utils.dart';
import '../models/diary_entry.dart';

/// 검색어 상태
final searchQueryProvider = StateProvider<String>((ref) => '');

/// ✅ (핵심) 실시간 일기 목록 StreamProvider
final diaryStreamProvider = StreamProvider.autoDispose<List<DiaryEntry>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return const Stream.empty();

  final repo = ref.watch(diaryRepositoryProvider);
  return repo.watchDiaries(userId);
});

/// ✅ 필터링된 일기 목록 (Stream 결과를 그대로 필터)
final filteredDiaryListProvider = Provider<AsyncValue<List<DiaryEntry>>>((ref) {
  final base = ref.watch(diaryStreamProvider);
  final query = ref.watch(searchQueryProvider);

  return base.whenData((entries) {
    final q = query.trim();
    if (q.isEmpty) return entries;

    return entries.where((e) {
      final title = e.title;   // title이 non-null이면 그대로, nullable면 ?? '' 처리
      final content = e.content;
      final date = e.date;

      return entryMatchesQuery(
        queryRaw: q,
        title: title ?? '',
        content: content ?? '',
        date: date,
      );
    }).toList();
  });
});

/// ✅ 최신 일기
final latestDiaryProvider = Provider<DiaryEntry?>((ref) {
  final state = ref.watch(diaryStreamProvider);

  return state.when(
    data: (list) => list.isEmpty ? null : list.last,
    loading: () => null,
    error: (_, __) => null,
  );
});
