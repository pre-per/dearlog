import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../call/models/conversation/call_day.dart';
import '../../diary/models/diary_entry.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';
import '../models/user_traits.dart';
import '../repository/user_repository.dart';

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
      diaries: [
        DiaryEntry(
          id: 'd1',
          date: DateTime.now().subtract(const Duration(days: 0)),
          title: '햇살 가득한 하루 ☀️',
          content: '오늘은 날씨도 좋고 기분도 한결 나아졌다. 산책하면서 마음이 많이 편안해졌다.',
          emotion: 'happy',
          imageUrls: ['https://images.unsplash.com/photo-1506744038136-46273834b3fb'],
        ),
        DiaryEntry(
          id: 'd2',
          date: DateTime.now().subtract(const Duration(days: 1)),
          title: '마음이 무거운 날',
          content: '아무 이유 없이 울적한 하루였다. 그래도 일기 쓰면서 조금은 털어낼 수 있었던 것 같다.',
          emotion: 'sad',
          imageUrls: ['https://images.unsplash.com/photo-1506744038136-46273834b3fb'],
        ),
        DiaryEntry(
          id: 'd3',
          date: DateTime.now().subtract(const Duration(days: 2)),
          title: '작은 일에도 화가 났던 하루',
          content: '별 것 아닌데도 짜증이 났다. 감정을 컨트롤하는 게 아직은 어려운 것 같다.',
          emotion: 'angry',
          imageUrls: ['https://images.unsplash.com/photo-1506744038136-46273834b3fb'],
        ),
      ],
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

