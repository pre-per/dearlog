import 'package:flutter/material.dart';
import '../providers/analysis_providers.dart';
import '../../shared_ui/utils/planet_asset_mapper.dart';
import 'keyword_color_palette.dart';

class KeywordBubble extends StatelessWidget {
  final KeywordMapItem item;
  final double radius;
  final VoidCallback onTap;

  const KeywordBubble({
    super.key,
    required this.item,
    required this.radius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glow = keywordGlowColor(item.emotion);
    final planet = planetAssetForEmotion(item.emotion);
    final fontSize = (radius * 0.34).clamp(11.0, 22.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: radius * 2,
        height: radius * 2,
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
              blurRadius: 38,
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
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1B2433)),
              ),
              Container(color: Colors.black.withOpacity(0.55)),
              DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Color(0x66000000),
                    ],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: glow.withOpacity(0.95),
                    width: 1.4,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(radius * 0.22),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.word,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: fontSize,
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
