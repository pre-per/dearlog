import 'package:flutter/material.dart';

class SettingMenuTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SettingMenuTile({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white, // 배경색 필요시 변경
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            if (trailing != null) trailing!,
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: Colors.black),
          ],
        ),
      ),
    );
  }
}
