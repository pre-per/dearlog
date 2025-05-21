import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/callday.dart';
import '../models/user_profile.dart';
import '../models/user_preferences.dart';
import '../models/user_traits.dart';
import '../repository/user_repository.dart';

const bool useDummyData = true;

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final userIdProvider = StateProvider<String?>((ref) => 'dev_user_001');

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  if (useDummyData) {
    final now = DateTime.now();
    return UserProfile(
      nickname: '깨꾹이',
      age: 25,
      gender: '남성',
      location: '서울',
      interests: ['운동', '영화', '개발'],
      createdAt: now,
      updatedAt: now,
      callDays: List.generate(9, (i) {
        final date = now.subtract(Duration(days: i));
        return CallDay(date: date, called: i.isEven); // 홀수 날은 미통화
      }),
    );
  }

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
