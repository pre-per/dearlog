/// 커뮤니티 피드의 감정 필터에 쓰이는 그룹 정의.
///
/// 일기 모델은 `emotion: String` 으로 자유로운 한국어 단어를 저장한다
/// (`planet_asset_mapper.dart` 참고). 같은 행성으로 매핑되는 단어들을 한 그룹으로
/// 묶어서, 사용자가 칩 하나만 눌러도 비슷한 감정의 글들이 모이게 한다.
class EmotionGroup {
  /// 내부 식별자 (필터 상태 저장용). UI 에 노출되지 않음.
  final String key;

  /// 칩에 표시될 라벨.
  final String label;

  /// 이 그룹에 속하는 일기 `emotion` 문자열들. Firestore `whereIn` 쿼리에 그대로 사용.
  final List<String> emotions;

  /// 칩 옆에 작게 띄울 행성 에셋 base name (확장자/경로 제외).
  final String moonAsset;

  const EmotionGroup({
    required this.key,
    required this.label,
    required this.emotions,
    required this.moonAsset,
  });
}

/// 5개 그룹. `planet_asset_mapper.dart` 의 매핑과 1:1 대응.
const List<EmotionGroup> emotionGroups = [
  EmotionGroup(
    key: 'happy',
    label: '행복',
    emotions: ['행복', '만족', '감사'],
    moonAsset: 'happy_moon',
  ),
  EmotionGroup(
    key: 'joy',
    label: '기쁨',
    emotions: ['기쁨', '설렘', '즐거움'],
    moonAsset: 'funny_moon',
  ),
  EmotionGroup(
    key: 'calm',
    label: '평온',
    emotions: ['평온', '안정', '차분'],
    moonAsset: 'green_moon',
  ),
  EmotionGroup(
    key: 'sad',
    label: '슬픔',
    emotions: ['슬픔', '외로움', '우울'],
    moonAsset: 'blue_moon',
  ),
  EmotionGroup(
    key: 'anger',
    label: '분노',
    emotions: ['분노', '짜증', '답답함'],
    moonAsset: 'orange_moon',
  ),
];

/// 그룹 키로 그룹 객체 lookup. 못 찾으면 null.
EmotionGroup? findEmotionGroup(String? key) {
  if (key == null) return null;
  for (final g in emotionGroups) {
    if (g.key == key) return g;
  }
  return null;
}
