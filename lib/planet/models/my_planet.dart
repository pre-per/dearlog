/// 사용자의 '나의 행성' 설정 — `users/{uid}` 문서의 `planet` 필드에 저장된다.
///
/// 화장(cosmetic) 정보만 담으므로 암호화하지 않는다(프로필처럼 식별성 PII 가
/// 아님). 방문자 수/별조각은 표시용이며, 1차에서는 별조각을 기존 통계로 파생해
/// 보여주고 경제(적립·차감)는 구현하지 않는다.
library;

/// 행성 공개 범위. 1차에서는 값 저장만 하고 커뮤니티 방문 연동은 다음 단계.
enum PlanetVisibility { public, anonymous, friends, private }

extension PlanetVisibilityX on PlanetVisibility {
  String get label {
    switch (this) {
      case PlanetVisibility.public:
        return '전체 공개';
      case PlanetVisibility.anonymous:
        return '익명 공개';
      case PlanetVisibility.friends:
        return '친구·팔로워만';
      case PlanetVisibility.private:
        return '비공개';
    }
  }

  String get description {
    switch (this) {
      case PlanetVisibility.public:
        return '누구나 내 행성에 방문할 수 있어요';
      case PlanetVisibility.anonymous:
        return '이름 없이 내 행성을 볼 수 있어요';
      case PlanetVisibility.friends:
        return '팔로워만 내 행성에 방문할 수 있어요';
      case PlanetVisibility.private:
        return '나만 내 행성을 볼 수 있어요';
    }
  }

  static PlanetVisibility parse(String? raw) {
    return PlanetVisibility.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => PlanetVisibility.anonymous,
    );
  }
}

class MyPlanet {
  final String planetName;
  final String basePlanetType;
  final PlanetVisibility visibility;

  /// 장착한 행성 아이템 id 목록(카테고리당 1개).
  final List<String> equippedPlanetItems;

  /// 장착한 Nova 아이템 id 목록(슬롯당 1개).
  final List<String> equippedNovaItems;

  /// 방문 받은 횟수. 커뮤니티 방문 연동 전까지는 0.
  final int visitorCount;

  const MyPlanet({
    required this.planetName,
    required this.basePlanetType,
    required this.visibility,
    required this.equippedPlanetItems,
    required this.equippedNovaItems,
    this.visitorCount = 0,
  });

  /// 행성을 아직 만들지 않은 사용자의 기본값(v2 에셋).
  /// 라벤더 행성 + 별 하나 + 별 든 노바(행복 표정)로 단정한 기본 모습.
  factory MyPlanet.initial(String nickname) {
    final name = nickname.trim();
    return MyPlanet(
      planetName: name.isNotEmpty ? '$name님의 행성' : '나의 행성',
      basePlanetType: 'planet_lavender_glow',
      visibility: PlanetVisibility.anonymous,
      equippedPlanetItems: const ['single_star'],
      equippedNovaItems: const [
        'nova_default_holding_star',
        'expression_happy',
      ],
      visitorCount: 0,
    );
  }

  MyPlanet copyWith({
    String? planetName,
    String? basePlanetType,
    PlanetVisibility? visibility,
    List<String>? equippedPlanetItems,
    List<String>? equippedNovaItems,
    int? visitorCount,
  }) {
    return MyPlanet(
      planetName: planetName ?? this.planetName,
      basePlanetType: basePlanetType ?? this.basePlanetType,
      visibility: visibility ?? this.visibility,
      equippedPlanetItems: equippedPlanetItems ?? this.equippedPlanetItems,
      equippedNovaItems: equippedNovaItems ?? this.equippedNovaItems,
      visitorCount: visitorCount ?? this.visitorCount,
    );
  }

  factory MyPlanet.fromJson(Map<String, dynamic> json) {
    List<String> ids(dynamic v) =>
        (v as List?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    return MyPlanet(
      planetName:
          (json['planetName'] as String?)?.trim().isNotEmpty == true
              ? (json['planetName'] as String).trim()
              : '나의 행성',
      basePlanetType: (json['basePlanetType'] as String?) ?? 'base_planet_gray',
      visibility: PlanetVisibilityX.parse(json['visibility'] as String?),
      equippedPlanetItems: ids(json['equippedPlanetItems']),
      equippedNovaItems: ids(json['equippedNovaItems']),
      visitorCount: (json['visitorCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'planetName': planetName,
    'basePlanetType': basePlanetType,
    'visibility': visibility.name,
    'equippedPlanetItems': equippedPlanetItems,
    'equippedNovaItems': equippedNovaItems,
    'visitorCount': visitorCount,
  };
}
