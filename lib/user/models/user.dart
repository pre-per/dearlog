import 'package:dearlog/user/models/user_preferences.dart';
import 'package:dearlog/user/models/user_profile.dart';
import 'package:dearlog/user/models/user_traits.dart';
import '../../call/models/conversation/call.dart';
import '../../diary/models/diary_entry.dart';

class UserModel {
  final String id; // Firebase UID
  final String email;
  final UserProfile profile;
  final UserTraits traits;
  final UserPreferences preferences;
  final bool isCompleted;

  UserModel({
    required this.id,
    required this.email,
    required this.profile,
    required this.traits,
    required this.preferences,
    this.isCompleted = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      profile: UserProfile.fromJson(json['profile']),
      traits: UserTraits.fromJson(json['traits']),
      preferences: UserPreferences.fromJson(json['preferences']),
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'profile': profile.toJson(),
    'traits': traits.toJson(),
    'preferences': preferences.toJson(),
    'isCompleted': isCompleted,
  };
}
