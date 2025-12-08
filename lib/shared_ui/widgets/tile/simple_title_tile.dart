import 'package:flutter/material.dart';

class SimpleTitleTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SimpleTitleTile({
    super.key,
    required this.title,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: 15, bottom: 15),
        decoration: const BoxDecoration(
          color: Colors.transparent, // 배경색 필요시 변경
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
            if (trailing != null) trailing!,
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
