import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/services/openai_service.dart';
import '../../app/di/providers.dart';
import '../../diary/models/diary_entry.dart';
import '../../diary/models/monthly_insight.dart';
import '../../diary/providers/diary_providers.dart';
import '../../diary/repository/insight_repository.dart';
import '../../user/providers/user_fetch_providers.dart';
import 'analysis_providers.dart';

// ─────────────────────────────────────────────────
// Repository / 서비스 provider
// ─────────────────────────────────────────────────

final insightRepositoryProvider = Provider<InsightRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return InsightRepository(firestore: db);
});

// ─────────────────────────────────────────────────
// 한 달 인사이트 상태
// ─────────────────────────────────────────────────

class MonthlyInsightState {
  /// 캐시된(또는 방금 생성된) 인사이트.
  final MonthlyInsight? insight;

  /// 생성 진행 중.
  final bool isLoading;

  /// 마지막 생성 실패 메시지.
  final String? error;

  const MonthlyInsightState({
    this.insight,
    this.isLoading = false,
    this.error,
  });

  MonthlyInsightState copyWith({
    MonthlyInsight? insight,
    bool? isLoading,
    Object? error = _sentinel,
    bool clearInsight = false,
  }) {
    return MonthlyInsightState(
      insight: clearInsight ? null : (insight ?? this.insight),
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();

  bool get isEmpty => insight == null && !isLoading && error == null;
}

// ─────────────────────────────────────────────────
// Notifier — selectedMonth 기준으로 캐시 로드 + 자동 생성 + 수동 갱신
// ─────────────────────────────────────────────────

class MonthlyInsightNotifier
    extends StateNotifier<MonthlyInsightState> {
  MonthlyInsightNotifier(this.ref) : super(const MonthlyInsightState()) {
    _bootstrap();
    // selectedMonth가 바뀌면 다시 로드.
    ref.listen(selectedMonthProvider, (_, __) => _bootstrap());
  }

  final Ref ref;

  Future<void> _bootstrap() async {
    final userId = ref.read(userIdProvider);
    final month = ref.read(selectedMonthProvider);
    final monthKey = MonthlyInsight.monthKeyFor(month.year, month.month);

    if (userId == null) {
      state = const MonthlyInsightState();
      return;
    }

    // 1) 캐시 fetch
    state = state.copyWith(clearInsight: true, isLoading: false, error: null);
    final cached =
        await ref.read(insightRepositoryProvider).fetch(userId, monthKey);

    if (cached != null) {
      state = state.copyWith(insight: cached);
      return;
    }

    // 2) 캐시 없음 — 현재 달이면 자동 생성, 과거 달이면 빈 상태로 둠 (수동 트리거 대기).
    if (month.isCurrent) {
      // diary stream이 데이터 들어왔을 때 자동 생성.
      // (diaryStreamProvider가 아직 로딩이면 한 번만 await)
      final diaries = await _waitForDiaries();
      final inMonth = _filterMonth(diaries, month);
      if (inMonth.isEmpty) {
        // 일기 없으면 자동 생성도 의미 없음. 빈 상태 유지.
        return;
      }
      await _generateAndSave(userId, monthKey, inMonth);
    }
    // 과거 달은 사용자가 명시적으로 생성하기 전까지 그대로.
  }

  Future<List<DiaryEntry>> _waitForDiaries() async {
    final async = ref.read(diaryStreamProvider);
    if (async.hasValue) return async.value!;
    // 한 번 await — 스트림이 첫 값을 줄 때까지.
    final completer = await ref
        .read(diaryStreamProvider.future)
        .timeout(const Duration(seconds: 10), onTimeout: () => const []);
    return completer;
  }

  List<DiaryEntry> _filterMonth(List<DiaryEntry> all, SelectedMonth m) {
    return all
        .where((d) => !d.date.isBefore(m.start) && d.date.isBefore(m.end))
        .toList();
  }

  /// 사용자가 "다시 생성" / "지금 만들기" 버튼 누른 경우.
  Future<void> regenerate() async {
    final userId = ref.read(userIdProvider);
    final month = ref.read(selectedMonthProvider);
    if (userId == null) return;

    final diaries = await _waitForDiaries();
    final inMonth = _filterMonth(diaries, month);
    if (inMonth.isEmpty) {
      state = state.copyWith(
        clearInsight: true,
        isLoading: false,
        error: '이 달의 일기가 없어서 회고를 만들 수 없어요.',
      );
      return;
    }

    final monthKey = MonthlyInsight.monthKeyFor(month.year, month.month);
    await _generateAndSave(userId, monthKey, inMonth);
  }

  Future<void> _generateAndSave(
    String userId,
    String monthKey,
    List<DiaryEntry> diaries,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final nickname =
          ref.read(userProfileProvider)?.nickname.trim() ?? '';
      final result = await OpenAIService().generateMonthlyInsight(
        monthKey: monthKey,
        diaries: diaries,
        userName: nickname,
      );
      await ref.read(insightRepositoryProvider).save(userId, result);
      if (!mounted) return;
      state = state.copyWith(insight: result, isLoading: false, error: null);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }
}

final monthlyInsightProvider = StateNotifierProvider<
    MonthlyInsightNotifier, MonthlyInsightState>(
  (ref) => MonthlyInsightNotifier(ref),
);
