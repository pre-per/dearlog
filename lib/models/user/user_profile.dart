class UserProfile {
  final String nickname;
  final int age;
  final String gender;
  final String location;

  UserProfile({
    required this.nickname,
    required this.age,
    required this.gender,
    required this.location,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    nickname: json['nickname'],
    age: json['age'],
    gender: json['gender'],
    location: json['location'],
  );

  Map<String, dynamic> toJson() => {
    'nickname': nickname,
    'age': age,
    'gender': gender,
    'location': location,
  };
}
