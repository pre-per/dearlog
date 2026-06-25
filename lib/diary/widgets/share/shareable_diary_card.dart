import 'package:dearlog/analysis/widget/keyword_color_palette.dart';
import 'package:dearlog/diary/models/diary_entry.dart';
import 'package:dearlog/diary/models/nlp_insight.dart';
import 'package:dearlog/shared_ui/utils/planet_asset_mapper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 외부 SNS 공유 카드에 들어갈 수 있는 콘텐츠 섹션.
/// 사용자가 옵션 패널의 ↑/↓ 버튼으로 순서를 바꿀 수 있으며, 카드는 이 순서대로 렌더링한다.
enum DiaryShareSection {
  illustration,
  content,
  emotion,
  nlp,
}

/// 외부 SNS 공유 카드의 콘텐츠 토글 + 순서 옵션.
class DiaryShareOptions {
  final bool includeIllustration;
  final bool includeContent;
  final bool includeEmotionSummary;
  final bool includeNlpInsight;

  /// 카드 안 섹션의 렌더링 순서. 길이는 항상 [DiaryShareSection.values.length].
  final List<DiaryShareSection> order;

  const DiaryShareOptions({
    required this.includeIllustration,
    required this.includeContent,
    required this.includeEmotionSummary,
    required this.includeNlpInsight,
    required this.order,
  });

  /// 진입 시점의 기본값 — 그림/본문/감정은 가능하면 ON, NLP 인사이트는 OFF.
  /// 순서는 그림 → 본문 → 감정 → NLP. 데이터가 없는 항목은 자동으로 OFF 로 시작.
  factory DiaryShareOptions.initialFor(DiaryEntry diary) {
    return DiaryShareOptions(
      includeIllustration: diary.imageUrls.isNotEmpty,
      includeContent: true,
      includeEmotionSummary: diary.analysis != null,
      includeNlpInsight: false,
      order: const [
        DiaryShareSection.illustration,
        DiaryShareSection.content,
        DiaryShareSection.emotion,
        DiaryShareSection.nlp,
      ],
    );
  }

  /// 해당 섹션이 토글 ON 상태인지.
  bool include(DiaryShareSection section) {
    switch (section) {
      case DiaryShareSection.illustration:
        return includeIllustration;
      case DiaryShareSection.content:
        return includeContent;
      case DiaryShareSection.emotion:
        return includeEmotionSummary;
      case DiaryShareSection.nlp:
        return includeNlpInsight;
    }
  }

  DiaryShareOptions copyWith({
    bool? includeIllustration,
    bool? includeContent,
    bool? includeEmotionSummary,
    bool? includeNlpInsight,
    List<DiaryShareSection>? order,
  }) =>
      DiaryShareOptions(
        includeIllustration: includeIllustration ?? this.includeIllustration,
        includeContent: includeContent ?? this.includeContent,
        includeEmotionSummary:
            includeEmotionSummary ?? this.includeEmotionSummary,
        includeNlpInsight: includeNlpInsight ?? this.includeNlpInsight,
        order: order ?? this.order,
      );
}

/// 외부 SNS 공유용 9:16 스토리형 카드.
///
/// 다크 글래스 톤을 유지하며 옵션에 따라 그림/본문/감정/NLP 섹션이 토글된다.
/// 하단 워터마크는 항상 표시.
class ShareableDiaryCard extends StatelessWidget {
  final DiaryEntry diary;
  final DiaryShareOptions options;

  const ShareableDiaryCard({
    super.key,
    required this.diary,
    required this.options,
  });

  static const _bgTop = Color(0xFF14182A);
  static const _bgBottom = Color(0xFF1F1830);
  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    // 카드 높이는 콘텐츠가 결정. 옵션이 적으면 짧아지고, NLP/감정까지 다 켜지면
    // 자연스럽게 길어진다. 9:16 고정 비율을 강제하지 않아 오버플로우가 발생하지 않음.
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: Stack(
          children: [
            // 은은한 별빛 글로우 (좌상 + 우하)
            Positioned(
              top: -60,
              left: -40,
              child: _glow(120, _gold.withOpacity(0.08)),
            ),
            Positioned(
              bottom: -80,
              right: -60,
              child: _glow(160, const Color(0xFF8EC9FF).withOpacity(0.10)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(date: diary.date),
                  const SizedBox(height: 14),
                  // 사용자가 설정한 순서대로 섹션 렌더링.
                  for (final section in options.order)
                    ..._buildSection(section, diary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 섹션 한 개의 위젯 + 다음 섹션과의 간격을 반환. 토글 OFF / 데이터 없음이면 빈 리스트.
  List<Widget> _buildSection(DiaryShareSection section, DiaryEntry diary) {
    switch (section) {
      case DiaryShareSection.illustration:
        if (!options.includeIllustration || diary.imageUrls.isEmpty) {
          return const [];
        }
        return [
          _Illustration(url: diary.imageUrls.first),
          const SizedBox(height: 14),
        ];
      case DiaryShareSection.content:
        if (!options.includeContent) return const [];
        return [
          _ContentBlock(title: diary.title, content: diary.content),
          const SizedBox(height: 14),
        ];
      case DiaryShareSection.emotion:
        if (!options.includeEmotionSummary || diary.analysis == null) {
          return const [];
        }
        return [
          _EmotionSummary(diary: diary),
          const SizedBox(height: 14),
        ];
      case DiaryShareSection.nlp:
        if (!options.includeNlpInsight || diary.nlpInsight == null) {
          return const [];
        }
        return [
          _NlpBlock(insight: diary.nlpInsight!),
          const SizedBox(height: 14),
        ];
    }
  }

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 상단 메타 — 날짜 + 작은 dearlog 마크
// ─────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final DateTime date;
  const _Header({required this.date});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          DateFormat('yyyy.M.d (E)', 'ko_KR').format(date),
          style: TextStyle(
            color: Colors.white.withOpacity(0.78),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            fontFamily: 'GowunBatang',
          ),
        ),
        const Spacer(),
        Image.asset(
          'asset/image/logo_white.png',
          height: 14,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// 그림일기 (1:1)
// ─────────────────────────────────────────────────
class _Illustration extends StatelessWidget {
  final String url;
  const _Illustration({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            // 캡쳐 시점에 이미 캐시된 상태여야 함. 실패는 placeholder.
            errorBuilder: (_, __, ___) => Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white.withOpacity(0.3),
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 본문 (제목 + 내용)
// ─────────────────────────────────────────────────
class _ContentBlock extends StatelessWidget {
  final String title;
  final String content;

  const _ContentBlock({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목은 2줄에서 자름 — 한 줄 본문 미리보기와 함께 길이가 폭주하지 않도록.
          if (title.trim().isNotEmpty)
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                height: 1.4,
                fontFamily: 'GowunBatang',
              ),
            ),
          if (title.trim().isNotEmpty && content.trim().isNotEmpty)
            const SizedBox(height: 8),
          // 본문은 길이 제한 없이 전체 표시 — 카드 높이가 본문 길이만큼 늘어남.
          if (content.trim().isNotEmpty)
            Text(
              content,
              style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontSize: 12.5,
                height: 1.55,
                fontFamily: 'GowunBatang',
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 감정 요약 (행성 + 인용)
// ─────────────────────────────────────────────────
class _EmotionSummary extends StatelessWidget {
  final DiaryEntry diary;
  const _EmotionSummary({required this.diary});

  @override
  Widget build(BuildContext context) {
    final analysis = diary.analysis!;
    final topEmotion =
        analysis.emotions.isNotEmpty ? analysis.emotions.first : null;
    final quote =
        analysis.evidence.isNotEmpty ? analysis.evidence.first : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topEmotion != null) _Planet(emotion: topEmotion.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 감정',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                if (topEmotion != null)
                  Text(
                    topEmotion.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                if (quote != null && quote.quote.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    '“${quote.quote}”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 11.5,
                      height: 1.45,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Planet extends StatelessWidget {
  final String emotion;
  const _Planet({required this.emotion});

  @override
  Widget build(BuildContext context) {
    final glow = keywordGlowColor(emotion);
    final asset = planetAssetForEmotion(emotion);
    return SizedBox(
      width: 44,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glow.withOpacity(0.5),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF1B2433)),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: glow.withOpacity(0.85),
                    width: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// NLP 인사이트 (필터 칩 + 헤드라인 1~2개)
// ─────────────────────────────────────────────────
class _NlpBlock extends StatelessWidget {
  final NLPInsight insight;
  const _NlpBlock({required this.insight});

  static const _accent = Color(0xFFB298FF);

  @override
  Widget build(BuildContext context) {
    final filters = insight.filters.take(2).toList();
    if (filters.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withOpacity(0.14),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withOpacity(0.35)),
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
                  color: _accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '오늘의 마음 인지 필터',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < filters.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _NlpRow(filter: filters[i]),
          ],
        ],
      ),
    );
  }
}

class _NlpRow extends StatelessWidget {
  final NLPFilter filter;
  const _NlpRow({required this.filter});

  @override
  Widget build(BuildContext context) {
    final displayTag = filter.tag.replaceAll('_', ' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _NlpBlock._accent.withOpacity(0.20),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _NlpBlock._accent.withOpacity(0.55)),
          ),
          child: Text(
            '#$displayTag',
            style: const TextStyle(
              color: _NlpBlock._accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          filter.headline,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.92),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.4,
            fontFamily: 'GowunBatang',
          ),
        ),
      ],
    );
  }
}

