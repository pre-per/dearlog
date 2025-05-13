import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../models/user_preferences.dart';
import '../models/user_traits.dart';
import '../repository/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final userIdProvider = StateProvider<String?>((ref) => 'dev_user_001');

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  final repo = ref.read(userRepositoryProvider);
  return repo.fetchProfile(userId);
});

final userPreferencesProvider = FutureProvider<UserPreferences?>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  final repo = ref.read(userRepositoryProvider);
  return repo.fetchPreferences(userId);
});

final userTraitsProvider = FutureProvider<UserTraits?>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  final repo = ref.read(userRepositoryProvider);
  return repo.fetchTraits(userId);
});
