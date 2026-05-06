import 'dart:ui';

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

    final newTitle = _titleController.text.trim();
    final newContent = _contentController.text.trim();

    if (newTitle.isEmpty || newContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('제목과 내용을 모두 입력해 주세요.'),
          backgroundColor: Color(0xFF1E1E2E),
        ),
      );
      return;
    }

    // copyWith 로 분석/NLP 인사이트/음악 추천/편지/AI 댓글 보존.
    // (예전엔 DiaryEntry() 직접 생성 → 부가 데이터가 모두 null 로 덮여 사라짐)
    final updatedDiary = widget.diary.copyWith(
      title: newTitle,
      content: newContent,
    );

    await DiaryRepository().saveDiary(userId, updatedDiary);
    ref.invalidate(latestDiaryProvider);
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
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            children: [
              TextField(
                cursorColor: Colors.white,
                style: TextStyle(color: Colors.white, fontFamily: 'Pretendard'),
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
                  style: TextStyle(color: Colors.white, fontFamily: 'Pretendard'),
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
      ),
    );
  }
}
