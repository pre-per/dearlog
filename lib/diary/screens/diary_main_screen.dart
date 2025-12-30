import 'package:dearlog/app.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

enum DiaryViewMode { planets, calendar }

class DiaryMainScreen extends ConsumerStatefulWidget {
  const DiaryMainScreen({super.key});

  @override
  ConsumerState createState() => _DiaryMainScreenState();
}

class _DiaryMainScreenState extends ConsumerState<DiaryMainScreen> {
  DiaryViewMode _viewMode = DiaryViewMode.planets;

  void _toggleViewMode() {
    setState(() {
      _viewMode =
      _viewMode == DiaryViewMode.planets
          ? DiaryViewMode.calendar
          : DiaryViewMode.planets;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final diariesAsync = ref.watch(filteredDiaryListProvider);
    final bool isCalendar = _viewMode == DiaryViewMode.calendar;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: _toggleViewMode,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                color: const Color(0x1affffff),
              ),
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    (_viewMode == DiaryViewMode.planets)
                        ? 'asset/icons/basic/calendar.svg'
                        : 'asset/icons/navigation/planet.svg',
                    height: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    (_viewMode == DiaryViewMode.planets) ? '캘린더 보기' : '행성 보기',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'GowunBatang'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiarySearchScreen()),
              );
            },
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

          return diariesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (e, _) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('일기를 불러오는 중 오류가 발생했어요.\n$e'),
                ),
            data: (diaries) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child:
                isCalendar
                    ? DiaryCalendarView(
                  key: const ValueKey('calendar'),
                  diaries: diaries,
                )
                    : DiaryPlanetView(
                  key: const ValueKey('planets'),
                  diaries: diaries,
                ),
              );
            },
          );
        },
        error:
            (err, _) =>
            Center(
              child: Text('사용자 정보를 불러올 수 없습니다\n오류:$err', softWrap: true),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// =======================
/// ✅ 행성(전체보기) 화면
/// =======================
class DiaryPlanetView extends StatelessWidget {
  final List<DiaryEntry> diaries;

  const DiaryPlanetView({super.key, required this.diaries});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 50, bottom: 100),
      itemCount: diaries.length,
      itemBuilder:
          (context, index) =>
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: _PlanetCard(
              diary: diaries[diaries.length - 1 - index],
              index: index,
              isLast: index == diaries.length - 1,
            ),
          ),
    );
  }
}

/// =======================
/// ✅ 캘린더 화면 (오버플로우 완전 제거 버전)
/// =======================
class DiaryCalendarView extends StatefulWidget {
  final List<DiaryEntry> diaries;

  const DiaryCalendarView({super.key, required this.diaries});

  @override
  State<DiaryCalendarView> createState() => _DiaryCalendarViewState();
}

class _DiaryCalendarViewState extends State<DiaryCalendarView> {
  DateTime _focusedMonth = DateTime(DateTime
      .now()
      .year, DateTime
      .now()
      .month);
  DateTime? _selectedDate;

  static const _weekLabels = ['일', '월', '화', '수', '목', '금', '토'];

  // ✅ 셀 높이/레이아웃 고정 (overflow 방지 핵심)
  static const double _cellExtent = 70; // Grid mainAxisExtent
  static const double _dayAreaHeight = 16; // 날짜 텍스트 영역
  static const double _planetMax = 40;
  static const double _planetMin = 15;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthTitle = DateFormat('yyyy년 MM월', 'ko_KR').format(_focusedMonth);

    final monthDiaries =
    widget.diaries.where((d) {
      return d.date.year == _focusedMonth.year &&
          d.date.month == _focusedMonth.month;
    }).toList();

    final diaryByDay = <DateTime, DiaryEntry>{};
    for (final d in monthDiaries) {
      final key = DateTime(d.date.year, d.date.month, d.date.day);
      diaryByDay.putIfAbsent(key, () => d);
    }

    final totalCount = monthDiaries.length;
    final cells = _buildCalendarCells(_focusedMonth);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 월 / 이동
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month - 1,
                        );
                        _selectedDate = null;
                      });
                    },
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month + 1,
                        );
                        _selectedDate = null;
                      });
                    },
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '총 $totalCount개의 행성이 있어요',
            style: TextStyle(fontSize: 16, color: Colors.grey[300]),
          ),
          const SizedBox(height: 22),

          // 요일 헤더
          Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Center(
                  child: Text(
                    _weekLabels[i],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // ✅ 달력 그리드 (셀 내부 Stack/Positioned로 overflow 원천 차단)
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 16,
              crossAxisSpacing: 10,
              mainAxisExtent: _cellExtent,
            ),
            itemCount: cells.length,
            itemBuilder: (context, index) {
              final cell = cells[index];
              final dateKey = DateTime(
                cell.date.year,
                cell.date.month,
                cell.date.day,
              );

              final isInMonth = cell.inCurrentMonth;
              final isToday = _isSameDay(cell.date, now);
              final isSelected =
                  _selectedDate != null &&
                      _isSameDay(cell.date, _selectedDate!);

              final diary = diaryByDay[dateKey];
              final planetName =
              diary == null
                  ? 'grey_moon'
                  : (planetBaseNameMap[diary.emotion] ?? 'grey_moon');

              final opacity = isInMonth ? 1.0 : 0.25;

              // ✅ 셀 높이 기준으로 행성 크기 계산 (절대 overflow 안 남)
              final planetSize =
              (_cellExtent - _dayAreaHeight).clamp(_planetMin, _planetMax);

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = cell.date);

                  // ✅ 일기 없는 날이면 이동 X (원하면 안내 띄우기)
                  if (diary == null) return;

                  // ✅ 일기 디테일로 이동
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiaryDetailScreen(diary: diary),
                    ),
                  );
                },
                child: Opacity(
                  opacity: opacity,
                  child: SizedBox(
                    height: _cellExtent,
                    child: Stack(
                      children: [
                        // 행성: 위쪽 중앙
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: SizedBox(
                              width: planetSize,
                              height: planetSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                        color:
                                        Colors.white.withOpacity(0.9),
                                        width: 2,
                                      )
                                          : null,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'asset/image/moon_images/$planetName.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),

                                  // ⭐ 오늘 표시 (정중앙)
                                  if (isToday)
                                    Container(
                                      width: planetSize * 0.50,
                                      height: planetSize * 0.50,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withOpacity(0.35),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.star_rounded,
                                          color: Colors.white,
                                          size: planetSize * 0.35,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 날짜: 아래쪽 중앙 (높이 고정)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: _dayAreaHeight,
                          child: Center(
                            child: Text(
                              '${cell.date.day}',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                color: Colors.white.withOpacity(
                                  isInMonth ? 0.85 : 0.55,
                                ),
                                fontSize: 12,
                                height: 1.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<_CalendarCell> _buildCalendarCells(DateTime focusedMonth) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;

    final startOffset = firstDay.weekday % 7;

    final prevMonthLastDay =
        DateTime(focusedMonth.year, focusedMonth.month, 0).day;
    final prevMonth = DateTime(focusedMonth.year, focusedMonth.month - 1, 1);
    final nextMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 1);

    final cells = <_CalendarCell>[];

    for (int i = 0; i < startOffset; i++) {
      final day = prevMonthLastDay - (startOffset - 1 - i);
      cells.add(
        _CalendarCell(
          date: DateTime(prevMonth.year, prevMonth.month, day),
          inCurrentMonth: false,
        ),
      );
    }

    for (int day = 1; day <= daysInMonth; day++) {
      cells.add(
        _CalendarCell(
          date: DateTime(focusedMonth.year, focusedMonth.month, day),
          inCurrentMonth: true,
        ),
      );
    }

    while (cells.length % 7 != 0) {
      final day = cells.length - (startOffset + daysInMonth) + 1;
      cells.add(
        _CalendarCell(
          date: DateTime(nextMonth.year, nextMonth.month, day),
          inCurrentMonth: false,
        ),
      );
    }

    return cells;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CalendarCell {
  final DateTime date;
  final bool inCurrentMonth;

  _CalendarCell({required this.date, required this.inCurrentMonth});
}

/// =======================
/// 행성 카드 (기존 유지)
/// =======================
class _PlanetCard extends StatelessWidget {
  final DiaryEntry diary;
  final int index;
  final bool isLast;

  const _PlanetCard({
    super.key,
    required this.diary,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLeft = index % 2 == 0;

    return SizedBox(
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!isLast)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: DashedOrbitPainter(isLeft: isLeft)),
              ),
            ),
          Positioned(
            left: isLeft ? 40 : null,
            right: isLeft ? null : 40,
            top: -20,
            child: GestureDetector(
              onTap:
                  () =>
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiaryDetailScreen(diary: diary),
                    ),
                  ),
              child: Image.asset(
                'asset/image/moon_images/${planetBaseNameMap[diary.emotion] ??
                    'grey_moon'}.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            left: isLeft ? 10 : null,
            right: isLeft ? null : 10,
            top: -30,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.grey[800],
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 15,
                ),
                child: Text(
                  DateFormat('MM/dd').format(diary.date),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashedOrbitPainter extends CustomPainter {
  final bool isLeft;
  final Color color;

  DashedOrbitPainter({
    required this.isLeft,
    this.color = const Color(0x66FFFFFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final startX = isLeft ? 40.0 + 50.0 : size.width - (40.0 + 50.0);
    final startY = 50.0;
    final endX = isLeft ? size.width - 90.0 : 90.0;
    final endY = size.height - 0.0;
    path.moveTo(startX, startY);
    final midX = (startX + endX) / 2;
    final cp1 = Offset(
      isLeft ? midX - 40 : midX + 40,
      startY + size.height * 0.10,
    );
    final cp2 = Offset(
      isLeft ? midX + 80 : midX - 80,
      startY + size.height * 0.55,
    );
    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, endX, endY);
    _drawDashedPath(canvas, path, paint, dash: 10, gap: 7);
  }

  void _drawDashedPath(Canvas canvas,
      Path path,
      Paint paint, {
        required double dash,
        required double gap,
      }) {
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedOrbitPainter oldDelegate) =>
      oldDelegate.isLeft != isLeft || oldDelegate.color != color;
}
