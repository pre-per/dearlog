class UserPreferences {
  final String preferredGender;
  final List<int> ageRange;
  final String relationshipType;

  UserPreferences({
    required this.preferredGender,
    required this.ageRange,
    required this.relationshipType,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      preferredGender: json['preferredGender'],
      ageRange: List<int>.from(json['ageRange']),
      relationshipType: json['relationshipType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferredGender': preferredGender,
      'ageRange': ageRange,
      'relationshipType': relationshipType,
    };
  }
}
