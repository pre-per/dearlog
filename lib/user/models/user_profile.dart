/// 사용자 프로필. 회원가입 단계에서 4가지 모두 채워야 한다.
///
/// 변경 이력:
/// - age:int → ageGroup:string (정확한 나이 대신 나잇대만 보관/노출)
/// - location 삭제 (사용처 없음)
/// - interests 추가 (관심사 최대 3개)
class UserProfile {
  final String nickname;

  /// '남자' | '여자' | '공개 안 함'
  final String gender;

  /// '10대' | '20대' | '30대' | '40대' | '50대' | '60대 이상'
  final String ageGroup;

  /// 최대 3개. 추천 16개 + 직접 입력 가능.
  final List<String> interests;

  const UserProfile({
    required this.nickname,
    required this.gender,
    required this.ageGroup,
    required this.interests,
  });

  /// 회원가입 직후/마이그레이션 fallback용 빈 프로필.
  factory UserProfile.empty() => const UserProfile(
        nickname: '',
        gender: '',
        ageGroup: '',
        interests: [],
      );

  /// 모든 필수 필드가 채워져 있는지. 회원가입 강제 진입 판단에 사용.
  bool get isComplete =>
      nickname.trim().isNotEmpty &&
      gender.trim().isNotEmpty &&
      ageGroup.trim().isNotEmpty &&
      interests.isNotEmpty;

  UserProfile copyWith({
    String? nickname,
    String? gender,
    String? ageGroup,
    List<String>? interests,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      ageGroup: ageGroup ?? this.ageGroup,
      interests: interests ?? List<String>.from(this.interests),
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        nickname: (json['nickname'] as String? ?? '').trim(),
        gender: (json['gender'] as String? ?? '').trim(),
        ageGroup: (json['ageGroup'] as String? ?? '').trim(),
        interests: (json['interests'] as List? ?? [])
            .map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'gender': gender,
        'ageGroup': ageGroup,
        'interests': interests,
      };
}
