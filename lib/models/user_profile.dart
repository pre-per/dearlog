class UserProfile {
  final String nickname;
  final int age;
  final String gender;
  final String location;
  final List<String> interests;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.nickname,
    required this.age,
    required this.gender,
    required this.location,
    required this.interests,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      nickname: json['nickname'],
      age: json['age'],
      gender: json['gender'],
      location: json['location'],
      interests: List<String>.from(json['interests']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'age': age,
      'gender': gender,
      'location': location,
      'interests': interests,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
