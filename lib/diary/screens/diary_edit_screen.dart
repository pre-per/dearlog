import 'package:dearlog/app.dart';

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
    return BaseScaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _saveEditedDiary,
            child: const Text(
              '수정 완료',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              cursorColor: Colors.white,
              style: TextStyle(color: Colors.white),
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TextField(
                cursorColor: Colors.white,
                style: TextStyle(color: Colors.white),
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '내용',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
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
