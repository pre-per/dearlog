import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/base_scaffold.dart';
import '../models/my_planet.dart';
import '../providers/planet_providers.dart';
import '../widgets/planet_emotion_summary.dart';
import '../widgets/planet_scene.dart';
import 'nova_decorate_screen.dart';
import 'planet_decorate_screen.dart';
import 'planet_visibility_sheet.dart';

/// '나의 행성' 상세. 메인 행성+Nova 씬과 꾸미기/공개 설정 진입.
class MyPlanetScreen extends ConsumerWidget {
  const MyPlanetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(planetCatalogProvider);
    final planet = ref.watch(myPlanetProvider);
    final emotions = ref.watch(recentEmotionSummaryProvider);
    final starPieces = ref.watch(starPieceCountProvider);

    return BaseScaffold(
      appBar: AppBar(title: const Text('나의 행성'), centerTitle: true),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            LayoutBuilder(
              builder:
                  (context, constraints) => Center(
                    child: PlanetScene(
                      planet: planet,
                      catalog: catalog,
                      size: constraints.maxWidth.clamp(0.0, 360.0).toDouble(),
                    ),
                  ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                planet.planetName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            if (emotions.isNotEmpty) ...[
              const SizedBox(height: 10),
              PlanetEmotionSummary(emotions: emotions, center: true),
            ],
            const SizedBox(height: 22),
            _StatsStrip(
              visitorCount: planet.visitorCount,
              starPieces: starPieces,
              visibilityLabel: planet.visibility.label,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.public_rounded,
                    label: '행성 꾸미기',
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => PlanetDecorateScreen(
                                  initial: planet,
                                  catalog: catalog,
                                ),
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Nova 꾸미기',
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => NovaDecorateScreen(
                                  initial: planet,
                                  catalog: catalog,
                                ),
                          ),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.lock_outline_rounded,
              label: '공개 설정',
              trailing: planet.visibility.label,
              wide: true,
              onTap: () => showPlanetVisibilitySheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  final int visitorCount;
  final int starPieces;
  final String visibilityLabel;

  const _StatsStrip({
    required this.visitorCount,
    required this.starPieces,
    required this.visibilityLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.group_outlined,
              label: '방문자',
              value: '$visitorCount',
            ),
          ),
          _divider(),
          Expanded(
            child: _Stat(
              icon: Icons.star_rounded,
              label: '별조각',
              value: '$starPieces',
              accent: const Color(0xFFFFD27A),
            ),
          ),
          _divider(),
          Expanded(
            child: _Stat(
              icon: Icons.visibility_outlined,
              label: '공개 범위',
              value: visibilityLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: Colors.white.withOpacity(0.08));
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _Stat({
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
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool wide;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisAlignment:
              wide ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: Colors.white.withOpacity(0.92)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (wide) ...[
              const Spacer(),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.white.withOpacity(0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
