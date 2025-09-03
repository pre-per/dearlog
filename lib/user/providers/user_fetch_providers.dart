import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../app/di/providers.dart'; // ⬅️ di에서 repo 주입
import '../models/user.dart';
import '../models/user_profile.dart';
import '../models/user_preferences.dart';
import '../models/user_traits.dart';

final userIdProvider = StateProvider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

final userProvider = FutureProvider<UserModel?>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  final repo = ref.read(userRepositoryProvider); // di 주입 사용
  return repo.fetchUser(userId);
});

final userProfileProvider = Provider<UserProfile?>((ref) {
  final user = ref.watch(userProvider).maybeWhen(data: (u) => u, orElse: () => null);
  return user?.profile;
});
final userPreferencesProvider = Provider<UserPreferences?>((ref) {
  final user = ref.watch(userProvider).maybeWhen(data: (u) => u, orElse: () => null);
  return user?.preferences;
});
final userTraitsProvider = Provider<UserTraits?>((ref) {
  final user = ref.watch(userProvider).maybeWhen(data: (u) => u, orElse: () => null);
  return user?.traits;
});
