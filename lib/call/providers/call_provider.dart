import 'package:dearlog/user/providers/user_fetch_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../call/models/conversation/call.dart';
import '../repository/call_repository.dart';

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository();
});

final userCallsProvider = FutureProvider<List<Call>>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return [];
  final repo = ref.read(callRepositoryProvider);
  return repo.fetchCalls(userId);
});

final findCallProvider = FutureProvider.family<Call?, String>((
  ref,
  callId,
) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  final repo = ref.read(callRepositoryProvider);
  return repo.getCallById(userId, callId);
});
