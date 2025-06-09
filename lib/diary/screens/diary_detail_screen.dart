import 'package:dearlog/diary/models/diary_entry.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
            Text(
              '생성 일시: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(diary.date)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.6,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.end,
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
