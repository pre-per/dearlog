import 'dart:ui';
import 'package:dearlog/app.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:dearlog/analysis/widget/today_summary_card.dart';

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

  Future<void> _updateDiary(DiaryEntry updated) async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    await DiaryRepository().saveDiary(userId, updated);
    setState(() => _diary = updated);
  }

  void _showLetterEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LetterBottomSheet(
        diary: _diary,
        onSave: _updateDiary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('yyyy년 MM월 dd일', 'ko_KR').format(_diary.date),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'GowunBatang'),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 그림 일기
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: _diary.imageUrls.isNotEmpty 
                ? Image.network(
                    _diary.imageUrls.first, 
                    width: double.infinity, 
                    height: 300, 
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 300,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text("그림일기를 불러오는 중...", style: TextStyle(color: Colors.white.withOpacity(0.7))),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Container(height: 300, color: Colors.white10),
            ),
            const SizedBox(height: 24),

            // 2. 일기 보기
            _paperCard(_diary),
            const SizedBox(height: 24),

            // 3. 오늘의 감정 & 해석 요약 카드
            TodaySummaryCard(diary: _diary),
            const SizedBox(height: 24),
            
            // 4. AI의 한 마디
            const Text("AI의 한 마디", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
              child: Text(
                _diary.aiComment ?? "AI가 글을 쓰다가 잠들어버렸어요..\n다음 일기에서 따뜻한 한 마디로 보답할게요!", 
                style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic)
              ),
            ),

            const SizedBox(height: 24),

            // 5. 내게 보내는 편지 버튼
            _ActionButton(
              title: "오늘의 내게 보내는 편지",
              onTap: _showLetterEditor,
            ),
            
            const SizedBox(height: 12),

            // 6. 대화 확인하기 버튼
            if (_diary.callId != null)
              _ActionButton(
                title: "대화 확인하기",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CallRecordScreen(callId: _diary.callId!),
                    ),
                  );
                },
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _ActionButton({required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.1),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterBottomSheet extends StatefulWidget {
  final DiaryEntry diary;
  final Future<void> Function(DiaryEntry) onSave;
  const _LetterBottomSheet({required this.diary, required this.onSave});
  @override
  State<_LetterBottomSheet> createState() => _LetterBottomSheetState();
}

class _LetterBottomSheetState extends State<_LetterBottomSheet> {
  late TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.diary.myLetter ?? "");
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.black.withOpacity(0.6),
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("나에게 쓰는 편지", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'GowunBatang')),
                    TextButton(
                      onPressed: () async {
                        await widget.onSave(widget.diary.copyWith(myLetter: _controller.text));
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text("보내기", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const Divider(color: Colors.white24),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.8),
                    decoration: const InputDecoration(
                      hintText: "오늘 하루 수고한 나에게...",
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _paperCard(DiaryEntry diary) {
  return Stack(
    children: [
      Positioned.fill(
        child: Image.asset('asset/image/diary_white_page.png', fit: BoxFit.fill),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(diary.title, style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.black87, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(diary.content, style: const TextStyle(fontSize: 14.5, height: 1.6, color: Colors.black)),
          ],
        ),
      ),
    ],
  );
}
