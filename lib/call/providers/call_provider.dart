import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/di/providers.dart';          // di
import '../../user/providers/user_fetch_providers.dart';
import '../models/conversation/call.dart';

final userCallsProvider = FutureProvider<List<Call>>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return [];
  final repo = ref.read(callRepositoryProvider); // di
  return repo.fetchCalls(userId);
});

final findCallProvider = FutureProvider.family<Call?, String>((ref, callId) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  final repo = ref.read(callRepositoryProvider); // di
  return repo.getCallById(userId, callId);
});
