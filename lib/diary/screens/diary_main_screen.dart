import 'dart:ui';

import 'package:dearlog/app.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class DiaryMainScreen extends ConsumerStatefulWidget {
  const DiaryMainScreen({super.key});

  @override
  ConsumerState createState() => _DiaryMainScreenState();
}

class _DiaryMainScreenState extends ConsumerState<DiaryMainScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(
        _scrollController.position.maxScrollExtent,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final diariesAsync = ref.watch(filteredDiaryListProvider); // ⬅️ 변경

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '일기장',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          GestureDetector(
            onTap: () {},
            child: SvgPicture.asset(
              'asset/icons/basic/search_glass.svg',
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const AuthErrorScreen();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: diariesAsync.when(
              loading:
                  () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('일기를 불러오는 중 오류가 발생했어요.\n$e'),
                  ),
              data:
                  (diaries) => Stack(
                    children: [
                      Positioned.fill(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 100, bottom: 100),
                          itemCount: diaries.length,
                          itemBuilder:
                              (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                child: _PlanetCard(
                                  diary: diaries[index],
                                  index: index,
                                  isLast: index == diaries.length - 1,
                                ),
                              ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // 월 선택
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Text(
                                            '2025년 12월',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '총 ${diaries.length}개의 행성이 있어요',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // 보기 변경
                                  Container(
                                    width: 75,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: Colors.grey[800],
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 5
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        GestureDetector(
                                          onTap: () {},
                                          child: Container(
                                            width: 32,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0x1dffffff)
                                            ),
                                            child: Center(
                                              child: const Icon(
                                                Icons.calendar_month,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {},
                                          child: Container(
                                            width: 32,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(0x1dffffff)
                                            ),
                                            child: Center(
                                              child: const Icon(
                                                Icons.view_agenda_rounded,
                                                color: Colors.white,
                                                size: 16,
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
                        ),
                      ),
                    ],
                  ),
            ),
          );
        },
        error:
            (err, _) => Center(
              child: Text('사용자 정보를 불러올 수 없습니다\n오류:$err', softWrap: true),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _PlanetCard extends StatelessWidget {
  final DiaryEntry diary;
  final int index;
  final bool isLast;

  const _PlanetCard({super.key, required this.diary, required this.index, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final bool isLeft = index % 2 == 0;

    return SizedBox(
      height: 220, // ✅ 사진 느낌은 높이가 중요. 필요하면 240~280까지 올려도 좋음
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1) 점선(궤도) 이미지 (뒤에 깔기)
          if (!isLast)
            Positioned(
              left: isLeft ? 70 : null,
              right: isLeft ? null : 70,
              top: 40,
              child: Image.asset(
                'asset/image/dot_line_${isLeft ? 'right' : 'left'}.png',
                width: 220,
                fit: BoxFit.contain,
              ),
            ),

          // 2) 행성 이미지
          Positioned(
            left: isLeft ? 40 : null,
            right: isLeft ? null : 40,
            top: -20,
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DiaryDetailScreen(diary: diary))),
              child: Image.asset(
                'asset/image/moon_images/${planetBaseNameMap[diary.emotion] ?? 'grey_moon'}.png',
                // ✅ diary에 따라 다른 행성이면 매핑해서 바꾸기
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 3) 텍스트/정보 박스 (행성 옆에)
          Positioned(
            left: isLeft ? 10 : 290,
            right: isLeft ? 290 : 10,
            top: -30,
            child: Container(
              width: 53,
              height: 43,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.grey[800],
              ),
              child: Center(
                child: Text(
                  DateFormat('MM/dd').format(diary.date).toString(),
                  style: TextStyle(fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
