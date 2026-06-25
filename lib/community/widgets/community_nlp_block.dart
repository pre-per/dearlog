import 'package:flutter/material.dart';

import '../models/nlp_filter_snapshot.dart';

/// 게시물 본문과 분리된 NLP 인지 필터 블록.
///
/// 사진 공유 카드의 _NlpBlock 톤을 그대로 재현 — 보라 그라데이션 + 칩(#태그) +
/// 굵은 헤드라인. 본문 텍스트와 시각적으로 명확히 구분되어 "이건 AI 분석이구나"
/// 가 한눈에 읽힌다.
///
/// [compact] 가 true 면 카드용 — 한 필터만 칩+한 줄 헤드라인으로 노출하고
/// 헤더 라벨/내부 여백을 줄여 피드에서 공간을 적게 차지한다.
class CommunityNlpBlock extends StatelessWidget {
  final List<NlpFilterSnapshot> filters;
  final bool compact;

  const CommunityNlpBlock({
    super.key,
    required this.filters,
    this.compact = false,
  });

  static const accent = Color(0xFFB298FF);

  @override
  Widget build(BuildContext context) {
    final visible = compact
        ? filters.take(1).toList()
        : filters.take(2).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final pad = compact
        ? const EdgeInsets.fromLTRB(11, 9, 11, 10)
        : const EdgeInsets.fromLTRB(14, 12, 14, 14);

    return Container(
      width: double.infinity,
      padding: pad,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.14),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '마음 인지 필터',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 7 : 10),
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _Row(filter: visible[i], compact: compact),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final NlpFilterSnapshot filter;
  final bool compact;
  const _Row({required this.filter, required this.compact});

  @override
  Widget build(BuildContext context) {
    final displayTag = filter.tag.replaceAll('_', ' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: CommunityNlpBlock.accent.withOpacity(0.20),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: CommunityNlpBlock.accent.withOpacity(0.55),
            ),
          ),
          child: Text(
            '#$displayTag',
            style: const TextStyle(
              color: CommunityNlpBlock.accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          filter.headline,
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.92),
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w700,
            height: 1.4,
            fontFamily: 'GowunBatang',
          ),
        ),
      ],
    );
  }
}
