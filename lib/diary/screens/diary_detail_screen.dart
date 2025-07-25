import 'package:dearlog/diary/models/diary_entry.dart';
import 'package:dearlog/diary/repository/diary_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../call/screens/call_record_screen.dart';
import '../../user/providers/user_fetch_providers.dart';
import 'diary_edit_screen.dart';

class DiaryDetailScreen extends ConsumerStatefulWidget {
  final DiaryEntry diary;

  const DiaryDetailScreen({super.key, required this.diary});

  @override
  ConsumerState<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends ConsumerState<DiaryDetailScreen> {
  late DiaryEntry _diary;

  @override
  void initState() {
    super.initState();
    _diary = widget.diary;
  }

  Future<void> _navigateToEdit() async {
    final updated = await Navigator.push<DiaryEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryEditScreen(diary: _diary),
      ),
    );

    if (updated != null) {
      setState(() {
        _diary = updated; // ← 수정된 일기로 갱신
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(userIdProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _navigateToEdit,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('일기 삭제'),
                    content: const Text('정말로 이 일기를 삭제할까요?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
                    ],
                  ),
                );

                if (confirm == true && userId != null) {
                  await DiaryRepository().deleteDiary(userId, _diary.id);
                  ref.invalidate(userProvider);
                  if (context.mounted) Navigator.pop(context);
                }
              } else if (value == 'view_call') {
                final callId = _diary.callId;
                if (callId != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CallRecordScreen(callId: callId)));
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'view_call', child: Text('대화 확인하기')),
              PopupMenuItem(value: 'delete', child: Text('삭제하기')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              _diary.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),
            Text(
              '생성 일시: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_diary.date)}',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.6, color: Colors.grey[500]),
            ),
            _diary.imageUrls.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
              height: 250,
              width: double.infinity,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _diary.imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        getEmotionIllustration(_diary.emotion),
                        scale: 5,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _diary.emotion,
              style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            Text(
              _diary.content,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// 감정 코드에 따른 기본 이미지 asset 경로 반환
String getEmotionIllustration(String emotion) {
  switch (emotion) {
    case '행복':
      return 'asset/illustrations/happy.png';
    case '슬픔':
      return 'asset/illustrations/sad.png';
    case '분노':
      return 'asset/illustrations/angry.png';
    case '불안':
      return 'asset/illustrations/fear.png';
    default:
      return 'asset/illustrations/neutral.png';
  }
}
