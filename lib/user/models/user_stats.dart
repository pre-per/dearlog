import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 사용자의 일기 기록 통계 — 랭킹 시스템의 단일 진실 공급원.
///
/// 저장 위치: 최상위 컬렉션 `user_stats/{uid}`.
/// 다른 사용자가 커뮤니티에서 작성자 랭크/스트릭을 표시하려면 읽을 수 있어야
/// 하므로 공개 read, write 는 Cloud Functions 만 (보안 규칙으로 락).
///
/// 모든 날짜는 KST 자정 기준으로 정규화되어 저장된다 — 타임존이 다른 기기에서
/// 작성해도 일관된 "일기 기준일" 을 보장.
class UserStats {
  /// 사용자가 일기를 작성한 고유 날짜의 수. 같은 날 여러 일기를 써도 1로 카운트.
  final int diaryCount;

  /// 현재 연속 기록 일수. 유예 1일 허용 — 하루 빠져도 다음 날 쓰면 유지,
  /// 이틀 연속 빠지면 0 으로 리셋.
  final int currentStreak;

  /// 역대 최장 연속 기록 일수. 현재 스트릭이 깨져도 보존된다.
  final int longestStreak;

  /// 가장 최근에 일기를 작성한 날짜 (KST 자정 기준). 신규 사용자는 null.
  final DateTime? lastDiaryDate;

  /// 통계가 마지막으로 갱신된 시각 — Cloud Function 이 일기 onWrite 트리거를
  /// 처리할 때마다 서버 시간으로 덮어쓴다.
  final DateTime updatedAt;

  const UserStats({
    required this.diaryCount,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastDiaryDate,
    required this.updatedAt,
  });

  /// 통계가 비어있는 신규 사용자용 기본값.
  factory UserStats.empty() => UserStats(
        diaryCount: 0,
        currentStreak: 0,
        longestStreak: 0,
        lastDiaryDate: null,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// 현재 [diaryCount] 에 해당하는 티어. count 가 어떤 임계값에도 못 미치면 null.
  RankTier? get tier => RankTier.forCount(diaryCount);

  /// 다음 티어. 이미 최고 티어이거나 시작 전이면 null.
  RankTier? get nextTier {
    final current = tier;
    if (current == null) return RankTier.all.first;
    final idx = RankTier.all.indexOf(current);
    if (idx == -1 || idx == RankTier.all.length - 1) return null;
    return RankTier.all[idx + 1];
  }

  /// 다음 티어까지 남은 일수. 다음 티어가 없으면 null.
  int? get daysToNextTier {
    final next = nextTier;
    if (next == null) return null;
    final remaining = next.threshold - diaryCount;
    return remaining > 0 ? remaining : 0;
  }

  UserStats copyWith({
    int? diaryCount,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastDiaryDate,
    bool clearLastDiaryDate = false,
    DateTime? updatedAt,
  }) {
    return UserStats(
      diaryCount: diaryCount ?? this.diaryCount,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastDiaryDate:
          clearLastDiaryDate ? null : (lastDiaryDate ?? this.lastDiaryDate),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      diaryCount: (json['diaryCount'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      lastDiaryDate: _parseDateOrNull(json['lastDiaryDate']),
      updatedAt:
          _parseDateOrNull(json['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'diaryCount': diaryCount,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      if (lastDiaryDate != null)
        'lastDiaryDate': Timestamp.fromDate(lastDiaryDate!),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

DateTime? _parseDateOrNull(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// 누적 일기 일수에 따라 부여되는 장기 랭크 티어 — 우주 테마.
///
/// 먼지 한 알에서 시작해 은하단까지 10단계로 우주적 스케일이 커지는 메타포.
/// 진입 임계값은 [threshold] (해당 일수 이상부터 이 티어).
/// 시각 자산은 `asset/image/level/{key}.png` (원형 PNG).
class RankTier {
  /// 이 티어로 진입하는 최소 일기 일수.
  final int threshold;

  /// UI 표시 이름.
  final String name;

  /// 식별용 키 — Firestore/analytics 및 이미지 파일명 매칭.
  final String key;

  /// 원형 PNG 자산 경로.
  final String imagePath;

  /// 보조 그라데이션 — 배지 풀 배경, 진행 바, 글로우 색상 등에 사용.
  /// 이미지 자체의 톤과 어우러지도록 선택.
  final List<Color> gradient;

  /// 배지 위 텍스트 컬러.
  final Color foreground;

  const RankTier({
    required this.threshold,
    required this.name,
    required this.key,
    required this.imagePath,
    required this.gradient,
    required this.foreground,
  });

  /// 임계값을 가장 가까이 충족하는 티어. count 가 [all] 의 첫 임계값보다 작으면 null.
  static RankTier? forCount(int count) {
    RankTier? matched;
    for (final t in all) {
      if (count >= t.threshold) {
        matched = t;
      } else {
        break;
      }
    }
    return matched;
  }

  /// 모든 티어 — threshold 오름차순. 우주 스케일이 점점 커진다.
  ///
  /// 참고: meteor 자산은 파일명이 `methor.png` (오타 그대로 사용).
  static const List<RankTier> all = [
    RankTier(
      threshold: 3,
      name: '먼지',
      key: 'dust',
      imagePath: 'asset/image/level/dust.png',
      gradient: [Color(0xFFB8B5C8), Color(0xFF6E6A85)],
      foreground: Colors.white,
    ),
    RankTier(
      threshold: 5,
      name: '유성',
      key: 'meteor',
      imagePath: 'asset/image/level/methor.png',
      gradient: [Color(0xFFFFB375), Color(0xFFE65A3D)],
      foreground: Colors.white,
    ),
    RankTier(
      threshold: 10,
      name: '소행성',
      key: 'asteroid',
      imagePath: 'asset/image/level/asteroid.png',
      gradient: [Color(0xFFC9A77F), Color(0xFF6F4E2C)],
      foreground: Colors.white,
    ),
    RankTier(
      threshold: 25,
      name: '달',
      key: 'moon',
      imagePath: 'asset/image/level/moon.png',
      gradient: [Color(0xFFE8EAF0), Color(0xFFA4ACB8)],
      foreground: Color(0xFF1A1F2E),
    ),
    RankTier(
      threshold: 50,
      name: '지구',
      key: 'earth',
      imagePath: 'asset/image/level/earth.png',
      gradient: [Color(0xFF66C7E5), Color(0xFF2E6FB7)],
      foreground: Colors.white,
    ),
    RankTier(
      threshold: 75,
      name: '행성',
      key: 'planet',
      imagePath: 'asset/image/level/planet.png',
      gradient: [Color(0xFFB48EE0), Color(0xFF5E3FB0)],
      foreground: Colors.white,
    ),
    RankTier(
      threshold: 100,
      name: '항성',
      key: 'sun',
      imagePath: 'asset/image/level/sun.png',
      gradient: [Color(0xFFFFE066), Color(0xFFFF8C42)],
      foreground: Color(0xFF5C3D00),
    ),
    RankTier(
      threshold: 150,
      name: '성단',
      key: 'star_cluster',
      imagePath: 'asset/image/level/star_cluster.png',
      gradient: [Color(0xFFCFE8FF), Color(0xFF6BB6FF)],
      foreground: Color(0xFF0E2A47),
    ),
    RankTier(
      threshold: 200,
      name: '은하',
      key: 'galaxy',
      imagePath: 'asset/image/level/galaxy.png',
      gradient: [Color(0xFF9B5DE5), Color(0xFF3C096C)],
      foreground: Color(0xFFE0AAFF),
    ),
    RankTier(
      threshold: 300,
      name: '은하단',
      key: 'galaxy_cluster',
      imagePath: 'asset/image/level/galaxy_cluster.png',
      gradient: [Color(0xFFFF6BCB), Color(0xFF6B5BFF)],
      foreground: Colors.white,
    ),
  ];
}

/// 현재 연속 스트릭에 따른 글로우 단계.
///
/// 1일 = 효과 없음. 2~4일 = 점진적으로 강해지는 화이트→웜 글로우.
/// 5일 이상은 골든 글로우 + 불꽃, 더 길어질수록 광선/블루골드/무지개로 진화.
class StreakGlowLevel {
  /// 진입 최소 연속일.
  final int minStreak;

  /// 글로우의 기본 색상.
  final Color color;

  /// 글로우 blur radius (BoxShadow 의 blurRadius).
  final double blurRadius;

  /// 글로우 확산 (BoxShadow 의 spreadRadius).
  final double spread;

  /// 우측 상단에 🔥 같은 아이콘을 띄울지.
  final bool showFlame;

  /// 펄스 애니메이션 적용 여부.
  final bool pulse;

  /// 펄스 강도 (0.0 ~ 1.0). pulse 가 false 면 무시.
  final double pulseIntensity;

  /// 무지개 멀티 컬러 글로우 (30일+ 특별 보상).
  final bool rainbow;

  const StreakGlowLevel({
    required this.minStreak,
    required this.color,
    required this.blurRadius,
    required this.spread,
    this.showFlame = false,
    this.pulse = false,
    this.pulseIntensity = 0.0,
    this.rainbow = false,
  });

  /// 현재 스트릭에 해당하는 글로우 단계. streak 가 1 이하면 null (효과 없음).
  static StreakGlowLevel? forStreak(int streak) {
    if (streak < 2) return null;
    StreakGlowLevel? matched;
    for (final lv in all) {
      if (streak >= lv.minStreak) {
        matched = lv;
      } else {
        break;
      }
    }
    return matched;
  }

  /// 모든 글로우 단계 — minStreak 오름차순.
  static const List<StreakGlowLevel> all = [
    StreakGlowLevel(
      minStreak: 2,
      color: Color(0xFFFFFFFF),
      blurRadius: 8,
      spread: 1,
      pulse: true,
      pulseIntensity: 0.2,
    ),
    StreakGlowLevel(
      minStreak: 3,
      color: Color(0xFFFFE9B0),
      blurRadius: 12,
      spread: 2,
      pulse: true,
      pulseIntensity: 0.3,
    ),
    StreakGlowLevel(
      minStreak: 4,
      color: Color(0xFFFFD27A),
      blurRadius: 16,
      spread: 3,
      pulse: true,
      pulseIntensity: 0.4,
    ),
    StreakGlowLevel(
      minStreak: 5,
      color: Color(0xFFFFB347),
      blurRadius: 20,
      spread: 4,
      showFlame: true,
      pulse: true,
      pulseIntensity: 0.55,
    ),
    StreakGlowLevel(
      minStreak: 7,
      color: Color(0xFFFF8C42),
      blurRadius: 26,
      spread: 6,
      showFlame: true,
      pulse: true,
      pulseIntensity: 0.7,
    ),
    StreakGlowLevel(
      minStreak: 14,
      color: Color(0xFFFFD27A),
      blurRadius: 30,
      spread: 7,
      showFlame: true,
      pulse: true,
      pulseIntensity: 0.8,
    ),
    StreakGlowLevel(
      minStreak: 30,
      color: Color(0xFFFFD27A),
      blurRadius: 34,
      spread: 8,
      showFlame: true,
      pulse: true,
      pulseIntensity: 0.9,
      rainbow: true,
    ),
  ];
}
