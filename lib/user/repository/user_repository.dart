import 'package:cloud_firestore/cloud_firestore.dart';
import '../../call/models/conversation/call_day.dart';
import '../../call/models/conversation/conversation.dart';
import '../../diary/models/diary_entry.dart';
import '../../match/models/match.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';
import '../models/user_traits.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserModel?> fetchUser(String userId) async {
    try {
      final docSnap = await _firestore.doc('users/$userId').get();
      if (!docSnap.exists) return null;

      final data = docSnap.data()!;
      return UserModel(
        id: userId,
        email: data['email'] ?? '',
        isCompleted: data['isCompleted'] ?? false,
        profile: UserProfile.fromJson(data['profile']),
        preferences: UserPreferences.fromJson(data['preferences']),
        traits: UserTraits.fromJson(data['traits']),
        callHistory: (data['callHistory'] as List<dynamic>? ?? [])
            .map((e) => CallDay.fromJson(e))
            .toList(),
        conversations: (data['conversations'] as List<dynamic>? ?? [])
            .map((e) => Conversation.fromJson(e))
            .toList(),
        matches: (data['matches'] as List<dynamic>? ?? [])
            .map((e) => Match.fromJson(e))
            .toList(),
        diaries: (data['diaries'] as List<dynamic>? ?? [])
            .map((e) => DiaryEntry.fromJson(e))
            .toList(),
      );
    } catch (e, st) {
      print('🔥 fetchUser error: $e');
      print(st);
      return null;
    }
  }

  Future<void> initializeNewUser({
    required String userId,
    required String email,
  }) async {
    try {
      await _firestore.doc('users/$userId').set({
        'email': email,
        'isCompleted': false,
        'profile': UserProfile(
          nickname: '',
          age: 0,
          gender: '',
          location: '',
        ).toJson(),
        'preferences': UserPreferences(
          preferredGender: '',
          ageRange: [0, 0],
          relationshipType: '',
        ).toJson(),
        'traits': UserTraits(
          emotions: [],
          personality: '',
          interestsScore: {},
          lastAnalyzedAt: DateTime.now(),
        ).toJson(),
        'callHistory': [],
        'conversations': [],
        'matches': [],
        'diaries': [],
      });
      print('✅ 신규 유저 초기화 완료: $userId');
    } catch (e, st) {
      print('🔥 initializeNewUser 실패: $e');
      print(st);
    }
  }

  Future<void> updateIsCompleted(String userId, bool completed) async {
    await _firestore.doc('users/$userId').update({
      'isCompleted': completed,
    });
  }

  Future<void> saveProfile(String userId, UserProfile profile) async {
    await _firestore.doc('users/$userId').set({
      'profile': profile.toJson(),
    }, SetOptions(merge: true));
  }

  Future<void> savePreferences(String userId, UserPreferences preferences) async {
    await _firestore.doc('users/$userId').set({
      'preferences': preferences.toJson(),
    }, SetOptions(merge: true));
  }

  Future<void> saveTraits(String userId, UserTraits traits) async {
    await _firestore.doc('users/$userId').set({
      'traits': traits.toJson(),
    }, SetOptions(merge: true));
  }

  Future<void> saveCallHistory(String userId, List<CallDay> callDays) async {
    await _firestore.doc('users/$userId').set({
      'callHistory': callDays.map((e) => e.toJson()).toList(),
    }, SetOptions(merge: true));
  }

  Future<void> saveConversations(String userId, List<Conversation> conversations) async {
    await _firestore.doc('users/$userId').set({
      'conversations': conversations.map((e) => e.toJson()).toList(),
    }, SetOptions(merge: true));
  }

  Future<void> saveMatches(String userId, List<Match> matches) async {
    await _firestore.doc('users/$userId').set({
      'matches': matches.map((e) => e.toJson()).toList(),
    }, SetOptions(merge: true));
  }

  Future<void> saveDiaries(String userId, List<DiaryEntry> diaries) async {
    await _firestore.doc('users/$userId').set({
      'diaries': diaries.map((e) => e.toJson()).toList(),
    }, SetOptions(merge: true));
  }
}
