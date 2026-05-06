import 'dart:math' as math;
import 'dart:ui';

import 'package:dearlog/app.dart';
import 'package:intl/intl.dart';

/// 분석 페이지의 "오늘의 마음 인지 필터" 카드.
///
/// NLP 신경언어프로그래밍 기반으로 일기에 드러난 내재된 동기 / 인지 필터를
/// 1~3개 추론해 보여준다. 비용 제어를 위해 자동 생성하지 않고,
/// 사용자가 "지금 분석하기"를 명시적으로 탭해야 OpenAI 호출이 발생.
///
/// 상태:
/// - [diary.analysis] == null  → "분석 데이터가 없어요" 안내
/// - [diary.nlpInsight] == null → "지금 분석하기" placeholder
/// - 생성 중                    → 로딩 뷰
/// - 생성됨                     → 플립 카드 캐러셀
/// - 에러                       → 메시지 + 다시 시도
class NLPInsightCard extends ConsumerStatefulWidget {
  final DiaryEntry diary;
  final Future<void> Function(DiaryEntry) onUpdate;

  const NLPInsightCard({
    super.key,
    required this.diary,
    required this.onUpdate,
  });

  @override
  ConsumerState<NLPInsightCard> createState() => _NLPInsightCardState();
}

class _NLPInsightCardState extends ConsumerState<NLPInsightCard> {
  bool _generating = false;
  String? _error;

  static const _gold = Color(0xFFFFD700);

  Future<void> _generate() async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final nickname = ref.read(userProfileProvider)?.nickname.trim() ?? '';
      final userName = nickname.isEmpty ? '당신' : nickname;

      final insight = await OpenAIService().generateNLPInsight(
        userName: userName,
        diary: widget.diary,
      );
      if (!mounted) return;

      final updated = widget.diary.copyWith(nlpInsight: insight);
      await widget.onUpdate(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.diary.analysis;
    final insight = widget.diary.nlpInsight;
    final hasCarousel = insight != null && insight.filters.isNotEmpty;

    // 캐러셀 모드는 카드들이 글래스 컨테이너 좌우 패딩 안에서도 충분한
    // 너비를 가지도록 GlassCard 패딩을 세로만 두고, 헤더는 자체 패딩으로 처리.
    if (hasCarousel) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Header(
                showRefresh: true,
                loading: _generating,
                onRefresh: _generating ? null : _generate,
              ),
            ),
            const SizedBox(height: 16),
            // 인사이트가 새로 생성되면 generatedAt이 바뀌고, 키가 바뀌면서
            // State가 재생성됨 → _colors / _pageController / _current 모두
            // 새 filters 길이에 맞게 새로 초기화되어 RangeError 방지.
            _CarouselLoadedView(
              key: ValueKey(insight.generatedAt),
              insight: insight,
            ),
          ],
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            showRefresh: insight != null,
            loading: _generating,
            onRefresh: _generating ? null : _generate,
          ),
          const SizedBox(height: 14),
          _body(analysis, insight),
        ],
      ),
    );
  }

  Widget _body(DiaryAnalysis? analysis, NLPInsight? insight) {
    if (analysis == null) {
      return const _NoAnalysisView();
    }
    if (_generating && insight == null) {
      return const _GeneratingView();
    }
    if (_error != null && insight == null) {
      return _ErrorView(message: _error!, onRetry: _generate);
    }
    if (insight == null) {
      return _IdleView(onTap: _generate);
    }
    // insight는 있지만 filters가 비어있는 케이스.
    return const _EmptyFiltersView();
  }
}

// ─────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool showRefresh;
  final bool loading;
  final VoidCallback? onRefresh;

  const _Header({
    required this.showRefresh,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _NLPInsightCardState._gold.withOpacity(0.15),
            border: Border.all(
                color: _NLPInsightCardState._gold.withOpacity(0.4)),
          ),
          child: const Center(
            child: Text('🧠', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘의 마음 인지 필터',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'NLP 신경언어프로그래밍 기반 심리 분석',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (showRefresh)
          _RefreshButton(loading: loading, onTap: onRefresh),
      ],
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _RefreshButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      valueColor: AlwaysStoppedAnimation(
                          _NLPInsightCardState._gold),
                    ),
                  )
                : Icon(
                    Icons.refresh,
                    size: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
            const SizedBox(width: 4),
            Text(
              loading ? '분석 중' : '다시 분석',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 분석 전 / 로딩 / 에러 / 빈 결과 상태 뷰
// ─────────────────────────────────────────────────

class _NoAnalysisView extends StatelessWidget {
  const _NoAnalysisView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '감정 분석 데이터가 없어 인지 필터를 만들 수 없어요.',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 12.5,
          height: 1.5,
        ),
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  final VoidCallback onTap;
  const _IdleView({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        Text(
          '오늘의 일기 속 단어 패턴으로\n무의식적 사고 필터를 비춰드릴게요',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.78),
            fontSize: 13,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: _NLPInsightCardState._gold.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: _NLPInsightCardState._gold.withOpacity(0.55)),
              boxShadow: [
                BoxShadow(
                  color: _NLPInsightCardState._gold.withOpacity(0.18),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology_outlined,
                    color: _NLPInsightCardState._gold, size: 16),
                SizedBox(width: 6),
                Text(
                  '지금 분석하기',
                  style: TextStyle(
                    color: _NLPInsightCardState._gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation(_NLPInsightCardState._gold),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '마음을 들여다보고 있어요',
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '인지 필터를 불러오지 못했어요',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _NLPInsightCardState._gold.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: _NLPInsightCardState._gold.withOpacity(0.5)),
            ),
            child: const Text(
              '다시 시도',
              style: TextStyle(
                color: _NLPInsightCardState._gold,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyFiltersView extends StatelessWidget {
  const _EmptyFiltersView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '오늘은 두드러진 인지 필터가 잡히지 않았어요.\n일기가 좀 더 쌓이면 패턴이 보일 거예요.',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 12.5,
          height: 1.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 캐러셀 로드 뷰: 가로 긴 플립 카드 N장 + 도트 인디케이터
// ─────────────────────────────────────────────────

class _CarouselLoadedView extends StatefulWidget {
  final NLPInsight insight;
  const _CarouselLoadedView({super.key, required this.insight});

  @override
  State<_CarouselLoadedView> createState() => _CarouselLoadedViewState();
}

class _CarouselLoadedViewState extends State<_CarouselLoadedView> {
  static const double _viewportFraction = 0.85;
  static const double _aspectRatio = 1.5; // 가로:세로 = 3:2

  late final PageController _pageController;
  late final List<Color> _colors;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: _viewportFraction);
    _colors = _assignPastelColors(widget.insight);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = widget.insight.filters;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth * _viewportFraction;
        final cardHeight = cardWidth / _aspectRatio;

        return Column(
          children: [
            SizedBox(
              height: cardHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: filters.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (ctx, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _FlipCard(
                      filter: filters[i],
                      accent: _colors[i],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _DotIndicator(
              count: filters.length,
              current: _current,
              colors: _colors,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  DateFormat('yyyy.M.d HH:mm')
                      .format(widget.insight.generatedAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────
// 플립 카드 — Y축 회전으로 앞/뒤 전환
// ─────────────────────────────────────────────────

class _FlipCard extends StatefulWidget {
  final NLPFilter filter;
  final Color accent;

  const _FlipCard({
    required this.filter,
    required this.accent,
  });

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_controller.isAnimating) return;
    if (_controller.value >= 0.5) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (ctx, _) {
          final value = _controller.value;
          final angle = value * math.pi;
          final isFront = angle <= math.pi / 2;

          // 앞면이 보이는 동안엔 _CardFront, 90도 넘어가면 _CardBack 으로 교체.
          // 뒷면은 추가 rotateY(pi) 로 거울상 보정.
          final child = isFront
              ? _CardFront(filter: widget.filter, accent: widget.accent)
              : Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child:
                      _CardBack(filter: widget.filter, accent: widget.accent),
                );

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // perspective
              ..rotateY(angle),
            alignment: Alignment.center,
            child: child,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 카드 앞면 — 파스텔 글래스모피즘 + 태그명 중앙
// ─────────────────────────────────────────────────

class _CardFront extends StatelessWidget {
  final NLPFilter filter;
  final Color accent;

  const _CardFront({required this.filter, required this.accent});

  @override
  Widget build(BuildContext context) {
    final displayTag = filter.tag.replaceAll('_', ' ');

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withOpacity(0.32),
                accent.withOpacity(0.10),
                Colors.white.withOpacity(0.04),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            border: Border.all(color: accent.withOpacity(0.45), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.18),
                blurRadius: 18,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 14,
                left: 16,
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'NLP 필터',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    displayTag,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.96),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: accent.withOpacity(0.55),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 16,
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      color: Colors.white.withOpacity(0.55),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '탭하여 뒤집기',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
// 카드 뒷면 — 태그 칩 + 헤드라인 + 본문 + 근거 키워드
// ─────────────────────────────────────────────────

class _CardBack extends StatelessWidget {
  final NLPFilter filter;
  final Color accent;

  const _CardBack({required this.filter, required this.accent});

  @override
  Widget build(BuildContext context) {
    final displayTag = filter.tag.replaceAll('_', ' ');

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.06),
                accent.withOpacity(0.12),
              ],
            ),
            border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withOpacity(0.55)),
                ),
                child: Text(
                  '#$displayTag',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                filter.headline,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (filter.body.trim().isNotEmpty)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Text(
                      filter.body,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (filter.evidenceKeywords.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: filter.evidenceKeywords
                      .take(4)
                      .map((k) => _EvidenceChip(word: k, accent: accent))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  final String word;
  final Color accent;
  const _EvidenceChip({required this.word, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.30)),
      ),
      child: Text(
        word,
        style: TextStyle(
          color: Colors.white.withOpacity(0.78),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 도트 인디케이터 — 활성 도트는 길어지고 카드 컬러로 변색
// ─────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  final List<Color> colors;

  const _DotIndicator({
    required this.count,
    required this.current,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? colors[i] : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────
// 파스텔 팔레트 + 카드별 색상 배정
// 같은 인사이트(generatedAt 동일)는 항상 같은 색 배치를 가짐.
// 새 인사이트가 생성되면 셔플로 다른 색 조합이 나오게 됨.
// ─────────────────────────────────────────────────

const _pastelPalette = <Color>[
  Color(0xFFFF9FB1), // 핑크
  Color(0xFFFFB97A), // 피치
  Color(0xFFFFE08A), // 옐로우
  Color(0xFF8EE5B1), // 민트
  Color(0xFF8EC9FF), // 스카이
  Color(0xFFB298FF), // 라벤더
  Color(0xFFFFA8D4), // 로즈
  Color(0xFF98F2E2), // 아쿠아
];

List<Color> _assignPastelColors(NLPInsight insight) {
  final n = insight.filters.length;
  final seed = insight.generatedAt.millisecondsSinceEpoch;
  final rng = math.Random(seed);
  final indices = List<int>.generate(_pastelPalette.length, (i) => i)
    ..shuffle(rng);
  return indices.take(n).map((i) => _pastelPalette[i]).toList();
}
