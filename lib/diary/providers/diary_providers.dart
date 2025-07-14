import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/diary_entry.dart';
import '../repository/diary_repository.dart';
import '../../user/providers/user_fetch_providers.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository();
});

final diaryListProvider = FutureProvider<List<DiaryEntry>>((ref) async {
  final userId = ref.watch(userIdProvider);
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.fetchDiaries(userId!);
});

final diaryListNotifierProvider = StateNotifierProvider<DiaryListNotifier, AsyncValue<List<DiaryEntry>>>((ref) {
  final repo = ref.watch(diaryRepositoryProvider);
  final userId = ref.watch(userIdProvider);
  return DiaryListNotifier(repo, userId!);
});

class DiaryListNotifier extends StateNotifier<AsyncValue<List<DiaryEntry>>> {
  final DiaryRepository repo;
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
