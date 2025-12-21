import 'dart:ui';

import 'package:dearlog/app.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';

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
      MaterialPageRoute(builder: (_) => DiaryEditScreen(diary: _diary)),
    );

    if (updated != null) {
      setState(() {
        _diary = updated; // ← 수정된 일기로 갱신
      });
    }
  }

  Future<bool> showDeleteConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true, // 바깥 눌러 닫기(원하면 false)
      barrierColor: Colors.black.withOpacity(0.45), // 배경 어둡게
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), // 블러
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 30,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[800], // 유리 느낌
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '일기를 정말 삭제하시겠어요?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '한 번 삭제하면 다시 되돌릴 수 없어요.\n잠시 더 가지고 있고 싶다면 닫아주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '그냥 둘래요',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFD75B3A),
                                // 주황/레드톤
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '삭제할게요',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: SvgPicture.asset('asset/icons/basic/pencil.svg'),
            onPressed: _navigateToEdit,
          ),
          IconButton(
            icon: SvgPicture.asset('asset/icons/basic/trashcan.svg'),
            onPressed: () async {
              final ok = await showDeleteConfirmDialog(context);
              if (!ok) return;

              // 여기서 실제 삭제 처리
              final userId = ref.read(userIdProvider);
              if (userId == null) return;

              await DiaryRepository().deleteDiary(
                userId,
                _diary.id,
              ); // delete 함수명은 너 repo에 맞게
              ref.invalidate(filteredDiaryListProvider);

              if (mounted) Navigator.pop(context); // 상세 화면 닫고 목록으로
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Image.asset(
                  'asset/image/moon_images/${planetBaseNameMap[_diary.emotion] ?? 'grey_moon'}.png',
                  height: 264,
                  width: 264,
                ),
              ),
              Positioned(
                top: 50,
                left: 110,
                right: 110,
                child: Container(
                  width: 150,
                  height: 45,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.grey,
                  ),
                  child: Center(
                    child: Text(
                      DateFormat('yyyy년 MM월 dd일').format(_diary.date),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: ListView(
                  children: [
                    const SizedBox(height: 100),
                    _paperCard(_diary),
                    const SizedBox(height: 20),
                    _imageCards(_diary.imageUrls),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => CallRecordScreen(callId: _diary.callId!),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Color(0x1dffffff),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 20,
                        ),
                        child: Center(
                          child: Text(
                            '대화 확인하기',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _paperCard(DiaryEntry diary) {
  return Container(
    width: double.infinity,
    // ✅ Stack이 내용 높이에 맞춰 늘어나도록: 배경을 fill로 깔기
    child: Stack(
      children: [
        // ✅ 배경은 "부모(Stack)의 최종 높이"를 전부 채움
        Positioned.fill(
          child: Image.asset(
            'asset/image/diary_white_page.png',
            fit: BoxFit.fill,
          ),
        ),

        // ✅ 이 Column이 Stack의 "높이"를 결정한다
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // ✅ 중요: 내용만큼만 높이
            children: [
              Text(
                diary.title,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.6,
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                diary.content,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Image.asset(
                'asset/image/horizontal_line.png',
                width: double.infinity,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                ),
                child: Text(
                  diary.emotion,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _imageCards(List<String> imageUrls) {
  return Column(
    children:
        imageUrls.map((url) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }).toList(),
  );
}

Widget _checkMessages(String callId) {
  return GestureDetector(
    onTap: () {},
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Color(0x1dffffff),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Center(child: Text('대화 확인하기', style: TextStyle(fontSize: 16))),
    ),
  );
}
