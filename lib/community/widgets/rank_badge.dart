import 'package:flutter/material.dart';

import '../../user/models/user_stats.dart';

/// 일기 누적 일수 기반 장기 랭크 배지.
///
/// 닉네임 옆에 다는 작은 캡슐 형태. 토스 증권의 "1억대 자산가" 배지를 참고했지만
/// 머티리얼 Chip 위젯은 쓰지 않고 글래스 톤의 그라데이션 컨테이너로 직접 그린다.
///
/// 두 가지 모드:
///   - [RankBadgeSize.compact]: 이모지만, 카드 헤더 같은 좁은 공간용.
///   - [RankBadgeSize.full]: 이모지 + 티어 이름, 프로필/상세 화면용.
enum RankBadgeSize { compact, full }

class RankBadge extends StatelessWidget {
  final RankTier tier;
  final RankBadgeSize size;

  const RankBadge({
    super.key,
    required this.tier,
    this.size = RankBadgeSize.compact,
  });

  /// 일수에서 직접 만들기. 어느 티어에도 도달하지 못했으면 null 반환 — 호출자가
  /// `if (badge != null) badge`로 분기하도록.
  static RankBadge? fromCount(int diaryCount,
      {RankBadgeSize size = RankBadgeSize.compact}) {
    final tier = RankTier.forCount(diaryCount);
    if (tier == null) return null;
    return RankBadge(tier: tier, size: size);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = size == RankBadgeSize.compact;

    if (isCompact) {
      // 닉네임 옆에 붙는 작은 원형 이미지. pill 배경 없이 이미지 자체가 배지 역할.
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: tier.gradient.last.withOpacity(0.45),
              blurRadius: 5,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            tier.imagePath,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // full — 작은 원형 이미지 + 이름 텍스트가 들어간 글래스 풀.
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tier.gradient
              .map((c) => c.withOpacity(0.85))
              .toList(growable: false),
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: tier.gradient.last.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: ClipOval(
              child: Image.asset(
                tier.imagePath,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            tier.name,
            style: TextStyle(
              color: tier.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
