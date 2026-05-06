import 'package:flutter/material.dart';

/// 분석 페이지의 섹션 라벨.
/// "AI 인사이트" / "활동과 기분" 같은 그룹 제목.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white.withOpacity(0.6), size: 16),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
