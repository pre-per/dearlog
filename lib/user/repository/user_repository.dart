import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';
import '../models/user_traits.dart';

class UserRepository {
  final FirebaseFirestore firestore;
  UserRepository({required this.firestore});

  Future<UserModel?> fetchUser(String userId) async {
    try {
      final docSnap = await firestore.doc('users/$userId').get();
      if (!docSnap.exists) return null;
      final data = docSnap.data()!;
      return UserModel(
        id: userId,
        email: data['email'] ?? '',
        isCompleted: data['isCompleted'] ?? false,
        profile: UserProfile.fromJson(data['profile']),
        preferences: UserPreferences.fromJson(data['preferences']),
        traits: UserTraits.fromJson(data['traits']),
      );
    } catch (e, st) {
      print('🔥 fetchUser error: $e\n$st');
      return null;
    }
  }

  Future<void> initializeNewUser({
    required String userId,
    required String email,
  }) async {
    try {
      await firestore.doc('users/$userId').set({
        'email': email,
        'isCompleted': false,
        'profile': UserProfile.empty().toJson(),
        'preferences': UserPreferences(preferredGender: '', ageRange: [0, 0], relationshipType: '').toJson(),
        'traits': UserTraits(emotions: [], personality: '', interestsScore: {}, lastAnalyzedAt: DateTime.now()).toJson(),
        'matches': [],
      });
      print('✅ 신규 유저 초기화 완료: $userId');
    } catch (e, st) {
      print('🔥 initializeNewUser 실패: $e\n$st');
    }
  }

  Future<void> updateIsCompleted(String userId, bool completed) async {
    await firestore.doc('users/$userId').update({'isCompleted': completed});
  }

  Future<void> saveProfile(String userId, UserProfile profile) async {
    await firestore.doc('users/$userId').set({'profile': profile.toJson()}, SetOptions(merge: true));
  }

  Future<void> savePreferences(String userId, UserPreferences preferences) async {
    await firestore.doc('users/$userId').set({'preferences': preferences.toJson()}, SetOptions(merge: true));
  }

  Future<void> saveTraits(String userId, UserTraits traits) async {
    await firestore.doc('users/$userId').set({'traits': traits.toJson()}, SetOptions(merge: true));
  }
}
