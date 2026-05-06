import 'package:flutter/material.dart';

/// 닉네임 첫 글자 + uid 기반 색상으로 만든 단순 아바타.
///
/// 익명 게시물에는 사용자별 식별이 새어나가지 않도록 회색 + '?' 로 통일한다.
class CommunityAvatar extends StatelessWidget {
  final String? authorUid;
  final String displayName;
  final bool isAnonymous;
  final double size;

  const CommunityAvatar({
    super.key,
    required this.authorUid,
    required this.displayName,
    required this.isAnonymous,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isAnonymous
        ? const Color(0xFF6B6B7A)
        : _colorFromSeed(authorUid ?? displayName);
    final letter = isAnonymous
        ? '?'
        : (displayName.isNotEmpty ? displayName.characters.first : '?');

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// uid 같은 안정적인 시드에서 결정적 색상을 뽑는다. 같은 uid 는 같은 색.
Color _colorFromSeed(String seed) {
  if (seed.isEmpty) return const Color(0xFF6B6B7A);
  int hash = 0;
  for (final code in seed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return _palette[hash % _palette.length];
}

const List<Color> _palette = [
  Color(0xFFE57373), // pastel red
  Color(0xFFF06292), // pastel pink
  Color(0xFFBA68C8), // pastel purple
  Color(0xFF9575CD), // pastel deep purple
  Color(0xFF7986CB), // pastel indigo
  Color(0xFF64B5F6), // pastel blue
  Color(0xFF4DD0E1), // pastel cyan
  Color(0xFF4DB6AC), // pastel teal
  Color(0xFF81C784), // pastel green
  Color(0xFFAED581), // pastel light green
  Color(0xFFFFD54F), // pastel amber
  Color(0xFFFFB74D), // pastel orange
];
