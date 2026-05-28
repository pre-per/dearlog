class UserPreferences {
  final String preferredGender;
  final List<int> ageRange;
  final String relationshipType;

  /// 익명 게시물/댓글에서도 내 랭크 배지와 스트릭 글로우를 노출할지.
  /// 기본 false — 익명일 땐 시각적 식별 단서도 함께 가려서 익명성을 보호.
  /// 사용자가 자랑하고 싶으면 설정에서 켤 수 있다.
  final bool showRankWhenAnonymous;

  UserPreferences({
    required this.preferredGender,
    required this.ageRange,
    required this.relationshipType,
    this.showRankWhenAnonymous = false,
  });

  UserPreferences copyWith({
    String? preferredGender,
    List<int>? ageRange,
    String? relationshipType,
    bool? showRankWhenAnonymous,
  }) {
    return UserPreferences(
      preferredGender: preferredGender ?? this.preferredGender,
      ageRange: ageRange ?? this.ageRange,
      relationshipType: relationshipType ?? this.relationshipType,
      showRankWhenAnonymous:
          showRankWhenAnonymous ?? this.showRankWhenAnonymous,
    );
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      preferredGender: json['preferredGender'] ?? '',
      ageRange: json['ageRange'] != null
          ? List<int>.from(json['ageRange'])
          : <int>[0, 0],
      relationshipType: json['relationshipType'] ?? '',
      showRankWhenAnonymous:
          (json['showRankWhenAnonymous'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferredGender': preferredGender,
      'ageRange': ageRange,
      'relationshipType': relationshipType,
      'showRankWhenAnonymous': showRankWhenAnonymous,
    };
  }
}
