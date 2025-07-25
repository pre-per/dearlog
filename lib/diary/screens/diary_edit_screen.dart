import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dearlog/diary/models/diary_entry.dart';
import 'package:dearlog/diary/repository/diary_repository.dart';
import 'package:dearlog/user/providers/user_fetch_providers.dart';

class DiaryEditScreen extends ConsumerStatefulWidget {
  final DiaryEntry diary;

  const DiaryEditScreen({super.key, required this.diary});

  @override
  ConsumerState<DiaryEditScreen> createState() => _DiaryEditScreenState();
}

class _DiaryEditScreenState extends ConsumerState<DiaryEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.diary.title);
    _contentController = TextEditingController(text: widget.diary.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveEditedDiary() async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;

    final updatedDiary = DiaryEntry(
      id: widget.diary.id,
      date: widget.diary.date,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      emotion: widget.diary.emotion,
      imageUrls: widget.diary.imageUrls,
      callId: widget.diary.callId,
    );

    await DiaryRepository().saveDiary(userId, updatedDiary);
    ref.invalidate(userProvider); // 사용자 데이터 갱신
    if (mounted) Navigator.pop(context, updatedDiary);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일기 수정'),
        actions: [
          TextButton(
            onPressed: _saveEditedDiary,
            child: const Text('저장', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: '내용'),
                maxLines: null,
                expands: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
