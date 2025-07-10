import 'package:dearlog/user/providers/user_fetch_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match.dart';
import '../repository/match_repository.dart';

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository();
});

final userMatchesProvider = FutureProvider<List<Match>>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return [];
  final repo = ref.read(matchRepositoryProvider);
  return repo.fetchMatches(userId);
});
