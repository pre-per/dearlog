import 'package:dearlog/user/providers/user_fetch_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match.dart';
import '../repository/match_repository.dart';

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository();
});

final userMatchesProvider = FutureProvider<List<Match>>((ref) async {
  if (useDummyData) {
    return [
      Match(
        matchId: 'match_001',
        targetUserId: 'user_002',
        matchScore: 0.92,
        reason: '성격과 관심사가 유사합니다.',
        status: 'pending',
        createdAt: DateTime.now().subtract(Duration(days: 1)),
      ),
      Match(
        matchId: 'match_002',
        targetUserId: 'user_003',
        matchScore: 0.88,
        reason: '최근 통화 스타일이 잘 맞습니다.',
        status: 'accepted',
        createdAt: DateTime.now().subtract(Duration(days: 3)),
      ),
    ];
  }

  final userId = ref.watch(userIdProvider);
  if (userId == null) return [];
  final repo = ref.read(matchRepositoryProvider);
  return repo.fetchMatches(userId);
});
