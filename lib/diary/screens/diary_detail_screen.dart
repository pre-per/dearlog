import 'package:dearlog/diary/models/diary_entry.dart';
import 'package:flutter/material.dart';

class DiaryDetailScreen extends StatelessWidget {
  final DiaryEntry diary;

  const DiaryDetailScreen({super.key, required this.diary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(diary.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 20),
            Text(
              diary.date.toString(),
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(
              height: 250,
              width: double.infinity,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(diary.imageUrls.first),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              diary.emotion,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              diary.content,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
