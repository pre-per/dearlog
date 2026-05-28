import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/providers.dart';
import '../models/user_stats.dart';
import 'user_fetch_providers.dart';

/// 임의 UID 의 user_stats 를 실시간 스트림. 커뮤니티 게시물/댓글의 작성자 UID 로
/// 호출. 같은 UID 에 여러 카드가 구독해도 Riverpod 가 단일 stream 으로 묶어준다.
final userStatsByUidProvider =
    StreamProvider.family<UserStats?, String>((ref, uid) {
  final repo = ref.watch(userStatsRepositoryProvider);
  return repo.watch(uid);
});

/// 현재 로그인 사용자의 통계. 로그아웃 상태면 null emit.
final myUserStatsProvider = StreamProvider<UserStats?>((ref) {
  final uid = ref.watch(userIdProvider);
  if (uid == null || uid.isEmpty) {
    return const Stream<UserStats?>.empty();
  }
  final repo = ref.watch(userStatsRepositoryProvider);
  return repo.watch(uid);
});

/// 저장된 currentStreak 이 오늘 시점에서도 유효한지 보정.
/// Cloud Function 은 일기 write 시점에만 갱신하므로, 그 후 시간이 흘러
/// 이틀 이상 일기를 안 쓴 사용자는 실제로는 스트릭이 0 인 상태이다.
///
/// 이 헬퍼는 stats.lastDiaryDate 와 오늘(KST) 자정을 비교해서:
///   - 0~1일 차: 저장된 currentStreak 그대로 반환
///   - 2일 이상: 0 으로 보정
int liveCurrentStreak(UserStats? stats) {
  if (stats == null) return 0;
  final last = stats.lastDiaryDate;
  if (last == null) return 0;
  final todayKst = _kstMidnight(DateTime.now());
  final lastKst = _kstMidnight(last);
  final diff = todayKst.difference(lastKst).inDays;
  if (diff > 1) return 0;
  return stats.currentStreak;
}

DateTime _kstMidnight(DateTime any) {
  final utc = any.toUtc();
  final kstMs = utc.millisecondsSinceEpoch + 9 * 3600 * 1000;
  final kst = DateTime.fromMillisecondsSinceEpoch(kstMs, isUtc: true);
  final y = kst.year;
  final m = kst.month;
  final d = kst.day;
  // KST midnight = UTC midnight − 9h
  return DateTime.fromMillisecondsSinceEpoch(
    DateTime.utc(y, m, d).millisecondsSinceEpoch - 9 * 3600 * 1000,
    isUtc: true,
  );
}
