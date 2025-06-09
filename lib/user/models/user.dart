import 'package:dearlog/user/models/user_preferences.dart';
import 'package:dearlog/user/models/user_profile.dart';
import 'package:dearlog/user/models/user_traits.dart';

import '../../call/models/conversation/call_day.dart';
import '../../call/models/conversation/conversation.dart';
import '../../diary/models/diary_entry.dart';
import '../../match/models/match.dart';

class User {
  final String id;
  final UserProfile profile;
  final UserTraits traits;
  final UserPreferences preferences;
  final List<CallDay> callHistory;
  final List<Conversation> conversations;
  final List<Match> matches;
  final List<DiaryEntry> diaries;

  User({
    required this.id,
    required this.profile,
    required this.traits,
    required this.preferences,
    required this.callHistory,
    required this.conversations,
    required this.matches,
    required this.diaries,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      profile: UserProfile.fromJson(json['profile']),
      traits: UserTraits.fromJson(json['traits']),
      preferences: UserPreferences.fromJson(json['preferences']),
      callHistory:
          (json['callHistory'] as List)
              .map((e) => CallDay.fromJson(e))
              .toList(),
      conversations:
          (json['conversations'] as List)
              .map((e) => Conversation.fromJson(e))
              .toList(),
      matches: (json['matches'] as List).map((e) => Match.fromJson(e)).toList(),
      diaries:
          (json['diaries'] as List).map((e) => DiaryEntry.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profile': profile.toJson(),
    'traits': traits.toJson(),
    'preferences': preferences.toJson(),
    'callHistory': callHistory.map((e) => e.toJson()).toList(),
    'conversations': conversations.map((e) => e.toJson()).toList(),
    'matches': matches.map((e) => e.toJson()).toList(),
    'diaries': diaries.map((e) => e.toJson()).toList(),
  };
}
