import 'package:flutter/material.dart';

/// 꾸미기 그리드의 아이템 한 칸. [imageAsset] 이 null 이면 '없음'(해제) 타일.
class DecorateItemTile extends StatelessWidget {
  final String? imageAsset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const DecorateItemTile({
    super.key,
    required this.imageAsset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? Colors.white.withOpacity(0.16)
                          : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        selected
                            ? const Color(0xFFFFD27A)
                            : Colors.white.withOpacity(0.10),
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child:
                    imageAsset == null
                        ? Icon(
                          Icons.block_rounded,
                          color: Colors.white.withOpacity(0.45),
                          size: 26,
                        )
                        : Image.asset(
                          imageAsset!,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white.withOpacity(0.6),
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
