import 'package:dearlog/app.dart';
import 'package:dearlog/analysis/widget/keyword_color_palette.dart';

/// 오늘의 감정 상태 요약 카드 (가로형).
///
/// 좌측: 행성(주요 감정 매칭) + 감정 텍스트 오버레이 (KeywordBubble 스타일)
/// 우측: 근거 라벨 + 인용문 + AI 해설
class TodaySummaryCard extends StatelessWidget {
  final DiaryEntry diary;
  const TodaySummaryCard({super.key, required this.diary});

  @override
  Widget build(BuildContext context) {
    final analysis = diary.analysis;

    if (analysis == null) {
      return const GlassCard(
        child: Text(
          '아직 분석할 일기가 없어요.\n오늘의 기록을 남겨보세요.',
          style: TextStyle(color: Colors.white70, height: 1.35),
        ),
      );
    }

    final topEmotion =
        analysis.emotions.isNotEmpty ? analysis.emotions.first : null;
    final quote =
        analysis.evidence.isNotEmpty ? analysis.evidence.first : null;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 감정 상태 요약',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (topEmotion != null)
                _PlanetEmotion(emotionName: topEmotion.name)
              else
                const _PlanetPlaceholder(),
              const SizedBox(width: 14),
              Expanded(
                child: _EvidenceBlock(quote: quote, hasEmotion: topEmotion != null),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 행성 안에 감정 텍스트가 오버레이된 동그란 위젯.
/// keyword_bubble 스타일을 따라가되 텍스트는 큰 감정 단어 한 줄.
class _PlanetEmotion extends StatelessWidget {
  final String emotionName;
  static const double _size = 56;

  const _PlanetEmotion({required this.emotionName});

  @override
  Widget build(BuildContext context) {
    final glow = keywordGlowColor(emotionName);
    final planet = planetAssetForEmotion(emotionName);

    return SizedBox(
      width: _size,
      height: _size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glow.withOpacity(0.55),
              blurRadius: 22,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: glow.withOpacity(0.25),
              blurRadius: 36,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                planet,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF1B2433)),
              ),
              Container(color: Colors.black.withOpacity(0.5)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.transparent, Color(0x66000000)],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: glow.withOpacity(0.95),
                    width: 1.4,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      emotionName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: -0.3,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.85),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
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

class _PlanetPlaceholder extends StatelessWidget {
  const _PlanetPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Icon(
        Icons.help_outline,
        color: Colors.white.withOpacity(0.4),
        size: 22,
      ),
    );
  }
}

class _EvidenceBlock extends StatelessWidget {
  final EvidenceQuote? quote;
  final bool hasEmotion;
  const _EvidenceBlock({required this.quote, required this.hasEmotion});

  @override
  Widget build(BuildContext context) {
    if (quote == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          hasEmotion
              ? '아직 근거를 정리하지 못했어요.'
              : '오늘의 주요 감정을 아직 정리하지 못했어요.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.45),
        ),
      );
    }
    final q = quote!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '근거',
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '“${q.quote}”',
          style: const TextStyle(color: Colors.white, height: 1.45, fontSize: 13.5),
        ),
        if (q.why.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            q.why,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              height: 1.45,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
