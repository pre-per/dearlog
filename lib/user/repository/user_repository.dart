import 'package:cloud_firestore/cloud_firestore.dart';
import '../../call/models/conversation/call.dart';
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

      final callSnap = await _firestore.collection('users/$userId/call').get();
      final calls = callSnap.docs.map((doc) => Call.fromJson(doc.data())).toList();

      final diarySnap = await _firestore.collection('users/$userId/diary').get();
      final diaries = diarySnap.docs.map((doc) => DiaryEntry.fromJson(doc.data())).toList();

      return UserModel(
        id: userId,
        email: data['email'] ?? '',
        isCompleted: data['isCompleted'] ?? false,
        profile: UserProfile.fromJson(data['profile']),
        preferences: UserPreferences.fromJson(data['preferences']),
        traits: UserTraits.fromJson(data['traits']),
        calls: calls,
        diaries: diaries,
        matches: (data['matches'] as List<dynamic>? ?? [])
            .map((e) => Match.fromJson(e))
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
        'matches': [],
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

  Future<void> saveCalls(String userId, List<Call> calls) async {
    final batch = _firestore.batch();
    final collectionRef = _firestore.collection('users/$userId/call');

    for (final call in calls) {
      final docRef = collectionRef.doc(call.callId);
      batch.set(docRef, call.toJson());
    }

    await batch.commit();
  }

  Future<void> saveMatches(String userId, List<Match> matches) async {
    await _firestore.doc('users/$userId').set({
      'matches': matches.map((e) => e.toJson()).toList(),
    }, SetOptions(merge: true));
  }

  Future<void> saveDiaries(String userId, List<DiaryEntry> diaries) async {
    final batch = _firestore.batch();
    final collectionRef = _firestore.collection('users/$userId/diary');

    for (final diary in diaries) {
      final docRef = collectionRef.doc();
      batch.set(docRef, diary.toJson());
    }

    await batch.commit();
  }
}
