import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:dearlog/app.dart';

class ElevatedCardContainer extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final String title;
  final Color backgroundColor;

  const ElevatedCardContainer({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.title = '',
    this.backgroundColor = const Color(0x1affffff),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
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
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
