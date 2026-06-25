import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/planet_providers.dart';
import '../screens/my_planet_screen.dart';
import 'planet_emotion_summary.dart';
import 'planet_scene.dart';

/// '마이' 탭 상단의 '나의 행성' 카드.
///
/// 행성+Nova 미리보기, 최근 감정 요약, 방문자/별조각, '내 행성 보기' CTA.
/// 카탈로그(번들 JSON)가 로드되기 전엔 같은 높이의 플레이스홀더를 보여줘
/// 레이아웃이 튀지 않게 한다.
class MyPlanetCard extends ConsumerWidget {
  const MyPlanetCard({super.key});

  void _open(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MyPlanetScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(planetCatalogProvider);
    final planet = ref.watch(myPlanetProvider);
    final emotions = ref.watch(recentEmotionSummaryProvider);
    final starPieces = ref.watch(starPieceCountProvider);

    return _GlassPanel(
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '나의 행성',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.55),
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            planet.planetName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          if (emotions.isNotEmpty) ...[
            const SizedBox(height: 8),
            PlanetEmotionSummary(emotions: emotions),
          ],
          const SizedBox(height: 18),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sceneSize =
                    constraints.maxWidth.clamp(0.0, 300.0).toDouble();
                return PlanetScene(
                  planet: planet,
                  catalog: catalog,
                  size: sceneSize,
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.group_outlined,
                  label: '방문자',
                  value: '${planet.visitorCount}',
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withOpacity(0.08),
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),
              Expanded(
                child: _StatCell(
                  icon: Icons.star_rounded,
                  label: '별조각',
                  value: '$starPieces',
                  accent: const Color(0xFFFFD27A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PrimaryButton(label: '내 행성 보기', onTap: () => _open(context)),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: accent.withOpacity(0.9)),
            const SizedBox(width: 5),
            Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_rounded,
              size: 17,
              color: Colors.white.withOpacity(0.9),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 전체를 감싸는 글래스 패널(탭 가능).
class _GlassPanel extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _GlassPanel({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
