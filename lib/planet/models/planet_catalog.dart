import 'dart:math' as math;

/// 나의 행성 & Nova 꾸미기 카탈로그 (v2 에셋 `asset/make_planet_assets_2`).
///
/// v2 는 v1 과 다르게:
///  - 카테고리 재편: 행성 아이템 = 고리/별/구름/오브제 (배경 없음), Nova = 포즈/표정.
///  - 캔버스 크기가 제각각이고 transform 이 제공되지 않아, 슬롯별 좌표·크기를
///    개발(여기 [ItemTransform])에서 직접 정의한다. (행성 중심 기준 비율 좌표)
///  - 행성/행성아이템 원본은 투명 풀해상도라 그대로 쓰고, Nova 원본은 배경이
///    baked 된 불투명이라 **투명 썸네일**(256²)을 렌더 소스로 쓴다.
///
/// 좌표계: [ItemTransform] 의 x,y 는 0~1 박스 비율(중심 기준), scale 은 박스 폭
/// 대비 배율. 행성 아이템은 행성 씬 박스 기준, 표정은 Nova 박스 기준.
const String kV2AssetRoot = 'asset/make_planet_assets_2';

String _thumbAsset(String id) => '$kV2AssetRoot/thumbnails/${id}_thumb.png';
String _planetBaseAsset(String id) =>
    '$kV2AssetRoot/assets/planets/base/$id.png';
String _planetItemAsset(String folder, String id) =>
    '$kV2AssetRoot/assets/planet_items/$folder/$id.png';

class ItemTransform {
  final double x;
  final double y;
  final double scale;
  final double rotation; // degrees

  const ItemTransform({
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1.0,
    this.rotation = 0,
  });

  static const ItemTransform identity = ItemTransform();

  double get rotationRad => rotation * math.pi / 180;
}

// ─────────────────────────────────────────────────
// 행성 (베이스 + 꾸미기 아이템)
// ─────────────────────────────────────────────────

class BasePlanet {
  final String id;
  final String name;

  const BasePlanet({required this.id, required this.name});

  String get asset => _planetBaseAsset(id);
  String get thumb => _thumbAsset(id);
}

/// 행성 꾸미기 아이템 카테고리(장착은 카테고리당 1개).
enum PlanetItemCategory { ring, star, cloud, object }

extension PlanetItemCategoryX on PlanetItemCategory {
  String get label {
    switch (this) {
      case PlanetItemCategory.ring:
        return '고리';
      case PlanetItemCategory.star:
        return '별';
      case PlanetItemCategory.cloud:
        return '구름';
      case PlanetItemCategory.object:
        return '오브제';
    }
  }

  /// 원본 풀해상도 PNG 가 들어있는 하위 폴더명.
  String get folder {
    switch (this) {
      case PlanetItemCategory.ring:
        return 'rings';
      case PlanetItemCategory.star:
        return 'stars';
      case PlanetItemCategory.cloud:
        return 'clouds';
      case PlanetItemCategory.object:
        return 'objects';
    }
  }

  /// 같은 카테고리 아이템은 공통 위치/zIndex 로 자동 배치(슬롯형).
  int get zIndex {
    switch (this) {
      case PlanetItemCategory.ring:
        return 2;
      case PlanetItemCategory.star:
        return 3;
      case PlanetItemCategory.cloud:
        return 4;
      case PlanetItemCategory.object:
        return 5;
    }
  }

  ItemTransform get transform {
    switch (this) {
      case PlanetItemCategory.ring:
        return const ItemTransform(x: 0.5, y: 0.5, scale: 1.02);
      case PlanetItemCategory.star:
        return const ItemTransform(x: 0.73, y: 0.23, scale: 0.30);
      case PlanetItemCategory.cloud:
        return const ItemTransform(x: 0.27, y: 0.75, scale: 0.42);
      case PlanetItemCategory.object:
        return const ItemTransform(x: 0.66, y: 0.67, scale: 0.30);
    }
  }
}

class PlanetItem {
  final String id;
  final String name;
  final PlanetItemCategory category;

  const PlanetItem({
    required this.id,
    required this.name,
    required this.category,
  });

  String get asset => _planetItemAsset(category.folder, id);
  String get thumb => _thumbAsset(id);
  int get zIndex => category.zIndex;
  ItemTransform get transform => category.transform;
}

// ─────────────────────────────────────────────────
// Nova (포즈 + 표정)
// ─────────────────────────────────────────────────

/// Nova 슬롯. v2 포즈는 안테나·가방·소품이 이미 포함된 완성형이라, 슬롯은
/// 포즈(바디)와 표정(머리 오버레이) 둘로 단순화한다.
enum NovaSlot { pose, face }

extension NovaSlotX on NovaSlot {
  String get label {
    switch (this) {
      case NovaSlot.pose:
        return '포즈';
      case NovaSlot.face:
        return '표정';
    }
  }

  int get zIndex {
    switch (this) {
      case NovaSlot.pose:
        return 0;
      case NovaSlot.face:
        return 9;
    }
  }

  /// 표정은 포즈 머리 중심에 맞춰 얹는다(렌더로 튜닝한 값). 포즈는 박스를 채움.
  ItemTransform get transform {
    switch (this) {
      case NovaSlot.pose:
        return ItemTransform.identity;
      case NovaSlot.face:
        return const ItemTransform(x: 0.5, y: 0.335, scale: 0.56);
    }
  }
}

class NovaItem {
  final String id;
  final String name;
  final NovaSlot slot;

  const NovaItem({required this.id, required this.name, required this.slot});

  /// 원본이 불투명이라 렌더·썸네일 모두 투명 썸네일을 쓴다.
  String get asset => _thumbAsset(id);
  String get thumb => _thumbAsset(id);
  int get zIndex => slot.zIndex;
  ItemTransform get transform => slot.transform;
}

// ─────────────────────────────────────────────────
// 카탈로그
// ─────────────────────────────────────────────────

class PlanetCatalog {
  final List<BasePlanet> basePlanets;
  final List<PlanetItem> planetItems;
  final List<NovaItem> novaItems;

  PlanetCatalog({
    required this.basePlanets,
    required this.planetItems,
    required this.novaItems,
  });

  late final Map<String, BasePlanet> _baseById = {
    for (final b in basePlanets) b.id: b,
  };
  late final Map<String, PlanetItem> _planetItemById = {
    for (final i in planetItems) i.id: i,
  };
  late final Map<String, NovaItem> _novaItemById = {
    for (final i in novaItems) i.id: i,
  };

  BasePlanet get defaultBasePlanet => basePlanets.first;

  BasePlanet basePlanetById(String? id) =>
      (id != null ? _baseById[id] : null) ?? defaultBasePlanet;

  PlanetItem? planetItemById(String id) => _planetItemById[id];
  NovaItem? novaItemById(String id) => _novaItemById[id];

  List<PlanetItem> planetItemsOf(PlanetItemCategory category) =>
      planetItems.where((i) => i.category == category).toList();

  List<NovaItem> novaItemsOf(NovaSlot slot) =>
      novaItems.where((i) => i.slot == slot).toList();

  NovaItem get defaultPose =>
      novaItems.firstWhere((i) => i.slot == NovaSlot.pose);

  /// v2 하드코딩 카탈로그. (위치/이름은 개발 정의 — JSON 에는 좌표가 없음)
  factory PlanetCatalog.v2() {
    return PlanetCatalog(
      basePlanets: const [
        BasePlanet(id: 'planet_lavender_glow', name: '라벤더 글로우'),
        BasePlanet(id: 'planet_blue_dream', name: '블루 드림'),
        BasePlanet(id: 'planet_mint_aurora', name: '민트 오로라'),
        BasePlanet(id: 'planet_rose_nebula', name: '로즈 네뷸라'),
      ],
      planetItems: const [
        // 고리
        PlanetItem(
          id: 'ring_thin_white',
          name: '얇은 흰 고리',
          category: PlanetItemCategory.ring,
        ),
        PlanetItem(
          id: 'ring_gold',
          name: '골드 고리',
          category: PlanetItemCategory.ring,
        ),
        PlanetItem(
          id: 'ring_violet',
          name: '바이올렛 고리',
          category: PlanetItemCategory.ring,
        ),
        PlanetItem(
          id: 'ring_blue',
          name: '블루 고리',
          category: PlanetItemCategory.ring,
        ),
        PlanetItem(
          id: 'ring_pink',
          name: '핑크 고리',
          category: PlanetItemCategory.ring,
        ),
        PlanetItem(
          id: 'ring_stardust',
          name: '별가루 고리',
          category: PlanetItemCategory.ring,
        ),
        // 별
        PlanetItem(
          id: 'single_star',
          name: '별 하나',
          category: PlanetItemCategory.star,
        ),
        PlanetItem(
          id: 'purple_star',
          name: '보라 별',
          category: PlanetItemCategory.star,
        ),
        PlanetItem(
          id: 'shooting_star',
          name: '별똥별',
          category: PlanetItemCategory.star,
        ),
        PlanetItem(
          id: 'sparkle_cluster',
          name: '반짝임 무리',
          category: PlanetItemCategory.star,
        ),
        PlanetItem(
          id: 'tiny_crosses',
          name: '작은 십자별',
          category: PlanetItemCategory.star,
        ),
        // 구름
        PlanetItem(
          id: 'cloud_white_lavender',
          name: '라벤더 구름',
          category: PlanetItemCategory.cloud,
        ),
        PlanetItem(
          id: 'cloud_purple',
          name: '보라 구름',
          category: PlanetItemCategory.cloud,
        ),
        PlanetItem(
          id: 'cloud_pink',
          name: '핑크 구름',
          category: PlanetItemCategory.cloud,
        ),
        PlanetItem(
          id: 'cloud_small',
          name: '작은 구름',
          category: PlanetItemCategory.cloud,
        ),
        // 오브제
        PlanetItem(
          id: 'object_jar_stars',
          name: '별 항아리',
          category: PlanetItemCategory.object,
        ),
        PlanetItem(
          id: 'object_crystal',
          name: '크리스털',
          category: PlanetItemCategory.object,
        ),
        PlanetItem(
          id: 'object_crescent_moon',
          name: '초승달',
          category: PlanetItemCategory.object,
        ),
        PlanetItem(
          id: 'object_diary_book',
          name: '다이어리',
          category: PlanetItemCategory.object,
        ),
        PlanetItem(
          id: 'object_flower_patch',
          name: '꽃밭',
          category: PlanetItemCategory.object,
        ),
        PlanetItem(
          id: 'object_heart_balloon',
          name: '하트 풍선',
          category: PlanetItemCategory.object,
        ),
      ],
      novaItems: const [
        // 포즈 (안테나·가방·소품 포함 완성형)
        NovaItem(
          id: 'nova_default_holding_star',
          name: '별 든 노바',
          slot: NovaSlot.pose,
        ),
        NovaItem(id: 'nova_pose_basic', name: '기본 포즈', slot: NovaSlot.pose),
        NovaItem(id: 'nova_pose_wave', name: '인사 포즈', slot: NovaSlot.pose),
        NovaItem(id: 'nova_pose_float', name: '둥실 포즈', slot: NovaSlot.pose),
        // 표정 (머리 오버레이)
        NovaItem(id: 'expression_happy', name: '행복', slot: NovaSlot.face),
        NovaItem(id: 'expression_excited', name: '신남', slot: NovaSlot.face),
        NovaItem(id: 'expression_sleepy', name: '졸림', slot: NovaSlot.face),
        NovaItem(id: 'expression_sad', name: '슬픔', slot: NovaSlot.face),
        NovaItem(id: 'expression_heart', name: '하트', slot: NovaSlot.face),
      ],
    );
  }
}
