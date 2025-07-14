import 'package:dearlog/user/models/user_preferences.dart';
import 'package:dearlog/user/models/user_profile.dart';
import 'package:dearlog/user/models/user_traits.dart';
import '../../call/models/conversation/call.dart';
import '../../diary/models/diary_entry.dart';
import '../../match/models/match.dart';

class UserModel {
  final String id; // Firebase UID
  final String email;
  final UserProfile profile;
  final UserTraits traits;
  final UserPreferences preferences;
  final List<Call> calls;
  final List<DiaryEntry> diaries;
  final List<Match> matches;
  final bool isCompleted;

  UserModel({
    required this.id,
    required this.email,
    required this.profile,
    required this.traits,
    required this.preferences,
    required this.calls,
    required this.diaries,
    required this.matches,
    this.isCompleted = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      profile: UserProfile.fromJson(json['profile']),
      traits: UserTraits.fromJson(json['traits']),
      preferences: UserPreferences.fromJson(json['preferences']),
      calls: (json['calls'] as List).map((e) => Call.fromJson(e)).toList(),
      diaries: (json['diaries'] as List).map((e) => DiaryEntry.fromJson(e)).toList(),
      matches: (json['matches'] as List).map((e) => Match.fromJson(e)).toList(),
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'profile': profile.toJson(),
    'traits': traits.toJson(),
    'preferences': preferences.toJson(),
    'calls': calls.map((e) => e.toJson()).toList(),
    'diaries': diaries.map((e) => e.toJson()).toList(),
    'matches': matches.map((e) => e.toJson()).toList(),
    'isCompleted': isCompleted,
  };
}
