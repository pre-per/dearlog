import 'package:flutter/material.dart';

class DiaryDetailScreen extends StatelessWidget {
  final String diary;
  const DiaryDetailScreen({super.key, required this.diary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 일기')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(diary, style: const TextStyle(fontSize: 16, height: 1.6)),
      ),
    );
  }
}
