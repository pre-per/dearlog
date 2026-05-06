import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 회원가입 마법사가 단계별로 모으는 임시 데이터.
/// 마지막(관심사) 단계에서 [UserRepository.saveProfile] 로 일괄 저장.
class OnboardingDraft {
  final String nickname;

  /// '남자' | '여자' | '공개 안 함'
  final String gender;

  /// '10대' | '20대' | ... | '60대 이상'
  final String ageGroup;

  /// 최대 3개.
  final List<String> interests;

  /// true면 디버그 흐름 — 마지막 저장을 스킵하고 스낵바만 띄움.
  /// 홈의 디버그 버튼에서 진입했을 때만 true.
  final bool isDebugRun;

  const OnboardingDraft({
    this.nickname = '',
    this.gender = '',
    this.ageGroup = '',
    this.interests = const [],
    this.isDebugRun = false,
  });

  OnboardingDraft copyWith({
    String? nickname,
    String? gender,
    String? ageGroup,
    List<String>? interests,
    bool? isDebugRun,
  }) {
    return OnboardingDraft(
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      ageGroup: ageGroup ?? this.ageGroup,
      interests: interests ?? this.interests,
      isDebugRun: isDebugRun ?? this.isDebugRun,
    );
  }
}

/// 화면 간 단계 데이터 공유. 각 단계가 자기 필드만 갱신.
final onboardingDraftProvider =
    StateProvider<OnboardingDraft>((ref) => const OnboardingDraft());

/// 성별 옵션.
const List<String> kGenderOptions = ['남자', '여자', '공개 안 함'];

/// 나잇대 옵션 (저연령 → 고연령).
const List<String> kAgeGroupOptions = [
  '10대',
  '20대',
  '30대',
  '40대',
  '50대',
  '60대 이상',
];
