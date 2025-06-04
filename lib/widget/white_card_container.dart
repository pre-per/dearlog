import 'package:flutter/material.dart';

class WhiteCardContainer extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final String title;

  const WhiteCardContainer({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.title = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // 둥근 모서리
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05), // 그림자 색상 (파스텔톤 그레이 느낌)
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ...children
        ],
      ),
    );
  }
}
