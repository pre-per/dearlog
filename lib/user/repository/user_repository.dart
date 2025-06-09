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

  Future<User?> fetchUser(String userId) async {
    try {
      // 문서 단건 fetch (DocumentSnapshot)
      final profileDoc = _firestore.doc('users/$userId/profile').get();
      final preferencesDoc = _firestore.doc('users/$userId/preferences').get();
      final traitsDoc = _firestore.doc('users/$userId/traits').get();
      final callHistoryDoc = _firestore.doc('users/$userId/callHistory').get();

      // 서브컬렉션 fetch (QuerySnapshot)
      final conversationsQuery = _firestore.collection('users/$userId/conversations').get();
      final matchesQuery = _firestore.collection('users/$userId/matches').get();
      final diariesQuery = _firestore.collection('users/$userId/diaries').get();

      // 병렬 실행
      final results = await Future.wait([
        profileDoc,
        preferencesDoc,
        traitsDoc,
        callHistoryDoc,
        conversationsQuery,
        matchesQuery,
        diariesQuery,
      ]);

      // 명확한 타입 캐스팅
      final profileSnap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final preferencesSnap = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final traitsSnap = results[2] as DocumentSnapshot<Map<String, dynamic>>;
      final callHistorySnap = results[3] as DocumentSnapshot<Map<String, dynamic>>;

      final conversationsSnap = results[4] as QuerySnapshot<Map<String, dynamic>>;
      final matchesSnap = results[5] as QuerySnapshot<Map<String, dynamic>>;
      final diariesSnap = results[6] as QuerySnapshot<Map<String, dynamic>>;

      // 모델 변환
      final profile = UserProfile.fromJson(profileSnap.data()!);
      final preferences = UserPreferences.fromJson(preferencesSnap.data()!);
      final traits = UserTraits.fromJson(traitsSnap.data()!);

      final callDays = (callHistorySnap.data()?['callDays'] as List<dynamic>? ?? [])
          .map((e) => CallDay.fromJson(e))
          .toList();

      final conversations = conversationsSnap.docs
          .map((doc) => Conversation.fromJson(doc.data()))
          .toList();

      final matches = matchesSnap.docs
          .map((doc) => Match.fromJson(doc.data()))
          .toList();

      final diaries = diariesSnap.docs
          .map((doc) => DiaryEntry.fromJson(doc.data()))
          .toList();

      return User(
        id: userId,
        profile: profile,
        preferences: preferences,
        traits: traits,
        callHistory: callDays,
        conversations: conversations,
        matches: matches,
        diaries: diaries,
      );
    } catch (e, st) {
      print('🔥 fetchUser error: $e');
      print(st);
      return null;
    }
  }

  Future<UserProfile?> fetchProfile(String userId) async {
    final doc = await _firestore.doc('users/$userId/profile').get();
    if (doc.exists) {
      return UserProfile.fromJson(doc.data()!);
    }
    return null;
  }

  Future<void> saveProfile(String userId, UserProfile profile) async {
    await _firestore.doc('users/$userId/profile').set(profile.toJson());
  }

  Future<UserPreferences?> fetchPreferences(String userId) async {
    final doc = await _firestore.doc('users/$userId/preferences').get();
    if (doc.exists) {
      return UserPreferences.fromJson(doc.data()!);
    }
    return null;
  }

  Future<void> savePreferences(String userId, UserPreferences preferences) async {
    await _firestore.doc('users/$userId/preferences').set(preferences.toJson());
  }

  Future<UserTraits?> fetchTraits(String userId) async {
    final doc = await _firestore.doc('users/$userId/traits').get();
    if (doc.exists) {
      return UserTraits.fromJson(doc.data()!);
    }
    return null;
  }

  Future<void> saveTraits(String userId, UserTraits traits) async {
    await _firestore.doc('users/$userId/traits').set(traits.toJson());
  }

  Future<List<CallDay>> fetchCallHistory(String userId) async {
    final doc = await _firestore.doc('users/$userId/callHistory').get();
    if (!doc.exists) return [];

    final data = doc.data();
    final rawList = data?['callDays'] as List<dynamic>?;

    if (rawList == null) return [];

    return rawList.map((e) => CallDay.fromJson(e)).toList();
  }

  Future<void> saveCallHistory(String userId, List<CallDay> callDays) async {
    final callDayList = callDays.map((e) => e.toJson()).toList();

    await _firestore.doc('users/$userId/callHistory').set({
      'callDays': callDayList,
    });
  }

}
