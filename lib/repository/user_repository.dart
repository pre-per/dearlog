import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../models/user_preferences.dart';
import '../models/user_traits.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
}
