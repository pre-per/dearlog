import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../call/models/conversation/call_day.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';
import '../models/user_traits.dart';
import '../repository/user_repository.dart';

/// UserRepository 의존성 주입
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

/// 현재 로그인된 Firebase 사용자 UID
final userIdProvider = StateProvider<String?>((ref) {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  return firebaseUser?.uid;
});

/// 전체 사용자 정보
final userProvider = FutureProvider<UserModel?>((ref) async {
  final userId = ref.watch(userIdProvider);
  print("userID: $userId");
  if (userId == null) return null;
  final repo = ref.read(userRepositoryProvider);
  return repo.fetchUser(userId);
});

/// 서브 정보들 (userProvider에서 추출해서 재사용)

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

final callHistoryProvider = Provider<List<CallDay>>((ref) {
  final user = ref.watch(userProvider).maybeWhen(data: (u) => u, orElse: () => null);
  return user?.callHistory ?? [];
});
