import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/diary/diary_entry.dart';
import '../../repository/diary/diary_repository.dart';
import '../user/user_fetch_providers.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository();
});

final diaryListProvider = FutureProvider<List<DiaryEntry>>((ref) async {
  if (useDummyData) {
    return [
      DiaryEntry(
        id: 'diary_001',
        date: DateTime.now().subtract(Duration(days: 1)),
        title: '감정적인 하루',
        content: '오늘은 친구랑 싸워서 기분이 안 좋았다...',
        emotion: 'sad',
        imageUrls: [],
      ),
      DiaryEntry(
        id: 'diary_002',
        date: DateTime.now().subtract(Duration(days: 2)),
        title: '즐거운 산책',
        content: '날씨가 좋아서 공원에 다녀왔다. 기분이 좋았다.',
        emotion: 'happy',
        imageUrls: [],
      ),
    ];
  }

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
      if (useDummyData) {
        state = AsyncValue.data([
          DiaryEntry(
            id: 'diary_001',
            date: DateTime.now().subtract(Duration(days: 1)),
            title: '감정적인 하루',
            content: '오늘은 친구랑 싸워서 기분이 안 좋았다...',
            emotion: 'sad',
            imageUrls: [],
          ),
          DiaryEntry(
            id: 'diary_002',
            date: DateTime.now().subtract(Duration(days: 2)),
            title: '즐거운 산책',
            content: '날씨가 좋아서 공원에 다녀왔다. 기분이 좋았다.',
            emotion: 'happy',
            imageUrls: [],
          ),
        ]);
        return;
      }

      final diaries = await repo.fetchDiaries(userId);
      state = AsyncValue.data(diaries);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addDiary(DiaryEntry entry) async {
    if (useDummyData) {
      // 개발 환경에서는 상태에 직접 추가 가능
      final current = state.value ?? [];
      state = AsyncValue.data([...current, entry]);
      return;
    }

    await repo.addDiary(userId, entry);
    await loadDiaries();
  }

  Future<void> deleteDiary(String diaryId) async {
    if (useDummyData) {
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((d) => d.id != diaryId).toList());
      return;
    }

    await repo.deleteDiary(userId, diaryId);
    await loadDiaries();
  }

  Future<void> updateDiary(DiaryEntry entry) async {
    if (useDummyData) {
      final current = state.value ?? [];
      final updated = current.map((e) => e.id == entry.id ? entry : e).toList();
      state = AsyncValue.data(updated);
      return;
    }

    await repo.updateDiary(userId, entry);
    await loadDiaries();
  }
}
