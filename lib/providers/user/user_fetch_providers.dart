import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/conversation/call_day.dart';
import '../../models/user/user.dart';
import '../../models/user/user_profile.dart';
import '../../models/user/user_preferences.dart';
import '../../models/user/user_traits.dart';
import '../../repository/user/user_repository.dart';

const bool useDummyData = true;

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final userIdProvider = StateProvider<String?>((ref) => 'dev_user_001');

final userProvider = FutureProvider<User?>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  if (useDummyData) {
    return User(
      id: userId,
      profile: UserProfile(
        nickname: '김철수',
        age: 25,
        gender: '남성',
        location: '서울',
      ),
      preferences: UserPreferences(
        preferredGender: '여성',
        ageRange: [24, 30],
        relationshipType: '연애',
      ),
      traits: UserTraits(
        emotions: ['행복', '기쁨'],
        personality: '외향적',
        interestsScore: {
          '운동': 0.8,
          '음악': 0.6,
          '독서': 0.9,
        },
        lastAnalyzedAt: DateTime.now().subtract(Duration(days: 1)),
      ),
      callHistory: [
        CallDay(date: DateTime.now(), called: true),
        CallDay(date: DateTime.now().subtract(Duration(days: 1)), called: true),
        CallDay(date: DateTime.now().subtract(Duration(days: 2)), called: false),
        CallDay(date: DateTime.now().subtract(Duration(days: 3)), called: false),
        CallDay(date: DateTime.now().subtract(Duration(days: 4)), called: false),
        CallDay(date: DateTime.now().subtract(Duration(days: 5)), called: true),
      ],
      conversations: [],
      matches: [],
      diaries: [],
    );
  }
  final userRepo = ref.read(userRepositoryProvider);
  return userRepo.fetchUser(userId);
});

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  if (useDummyData) {
    return UserProfile(
      nickname: '김철수',
      age: 25,
      gender: '남성',
      location: '서울',
    );
  }

  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  final repo = ref.read(userRepositoryProvider);
  return repo.fetchProfile(userId);
});


final userPreferencesProvider = FutureProvider<UserPreferences?>((ref) async {
  if (useDummyData) {
    return UserPreferences(
      preferredGender: '여성',
      ageRange: [24, 30],
      relationshipType: '연애',
    );
  }

  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  final repo = ref.read(userRepositoryProvider);
  return repo.fetchPreferences(userId);
});

final userTraitsProvider = FutureProvider<UserTraits?>((ref) async {
  if (useDummyData) {
    return UserTraits(
      emotions: ['행복', '기쁨'],
      personality: '외향적',
      interestsScore: {
        '운동': 0.8,
        '음악': 0.6,
        '독서': 0.9,
      },
      lastAnalyzedAt: DateTime.now().subtract(Duration(days: 1)),
    );
  }

  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  final repo = ref.read(userRepositoryProvider);
  return repo.fetchTraits(userId);
});

final callHistoryProvider = FutureProvider<List<CallDay>>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return [];
  final repo = ref.read(userRepositoryProvider);
  return repo.fetchCallHistory(userId);
});

