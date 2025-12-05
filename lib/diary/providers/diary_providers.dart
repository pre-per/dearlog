import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/di/providers.dart';           // di
import '../../user/providers/user_fetch_providers.dart';
import '../../shared_ui/utils/search_utils.dart';
import '../models/diary_entry.dart';

/// 검색어 상태
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 필터링된 일기 목록 Provider
final filteredDiaryListProvider = Provider<AsyncValue<List<DiaryEntry>>>((ref) {
  final base  = ref.watch(diaryListProvider);    // 원본 비동기 목록
  final query = ref.watch(searchQueryProvider);  // 입력 쿼리

  return base.whenData((entries) {
    if (query.trim().isEmpty) return entries;

    return entries.where((e) {
      // ✅ DiaryEntry의 실제 필드명에 맞춰 주세요.
      // 아래는 예시: title, content, date(DateTime)
      final String title   = (e.title ?? '');
      final String content = (e.content ?? '');
      final DateTime? date = e.date; // ⬅️ DateTime 확정!

      return entryMatchesQuery(
        queryRaw: query,
        title: title,
        content: content,
        date: date,
      );
    }).toList();
  });
});


final diaryListProvider = FutureProvider<List<DiaryEntry>>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return [];
  final repo = ref.read(diaryRepositoryProvider); // di
  return repo.fetchDiaries(userId);
});

final diaryListNotifierProvider =
StateNotifierProvider<DiaryListNotifier, AsyncValue<List<DiaryEntry>>>((ref) {
  final repo = ref.read(diaryRepositoryProvider); // di
  final userId = ref.watch(userIdProvider) ?? '';
  return DiaryListNotifier(repo, userId);
});

class DiaryListNotifier extends StateNotifier<AsyncValue<List<DiaryEntry>>> {
  final dynamic repo; // DiaryRepository
  final String userId;

  DiaryListNotifier(this.repo, this.userId) : super(const AsyncValue.loading()) {
    loadDiaries();
  }

  Future<void> loadDiaries() async {
    try {
      final diaries = await repo.fetchDiaries(userId);
      state = AsyncValue.data(diaries);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveDiary(DiaryEntry entry) async {
    await repo.saveDiary(userId, entry);
    await loadDiaries();
  }

  Future<void> deleteDiary(String diaryId) async {
    await repo.deleteDiary(userId, diaryId);
    await loadDiaries();
  }
}
