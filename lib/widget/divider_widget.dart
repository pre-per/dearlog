import 'package:flutter/material.dart';

class DividerWidget extends StatelessWidget {
  const DividerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Divider(color: Colors.grey[300], indent: 10, endIndent: 10),
        const SizedBox(height: 20),
      ],
    );
  }
}
