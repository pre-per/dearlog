import 'package:dearlog/diary/models/diary_entry.dart';
import 'package:dearlog/diary/repository/diary_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../call/screens/call_record_screen.dart';
import '../../user/providers/user_fetch_providers.dart';

class DiaryDetailScreen extends ConsumerWidget {
  final DiaryEntry diary;

  const DiaryDetailScreen({super.key, required this.diary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(userIdProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: const Text('일기 삭제'),
                        content: const Text('정말로 이 일기를 삭제할까요?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                );

                if (confirm == true && userId != null) {
                  await DiaryRepository().deleteDiary(userId, diary.id);
                  ref.invalidate(userProvider);
                  if (context.mounted) Navigator.pop(context);
                }
              } else if (value == 'view_call') {
                final callId = diary.callId;
                if (callId != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CallRecordScreen(callId: callId)));
                }
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'view_call',
                    child: Text('대화 확인하기'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('삭제하기')),
                ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 0),
            Text(
              diary.title,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),
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
            diary.imageUrls.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
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
