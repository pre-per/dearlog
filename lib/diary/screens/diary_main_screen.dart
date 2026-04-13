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
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final diariesAsync = ref.watch(filteredDiaryListProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text(
          '나의 일기',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'GowunBatang',
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
          const SizedBox(width: 20),
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
            data: (diaries) => DiaryCalendarView(diaries: diaries),
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
/// ✅ 캘린더 화면
/// =======================
class DiaryCalendarView extends StatefulWidget {
  final List<DiaryEntry> diaries;

  const DiaryCalendarView({super.key, required this.diaries});

  @override
  State<DiaryCalendarView> createState() => _DiaryCalendarViewState();
}

class _DiaryCalendarViewState extends State<DiaryCalendarView> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  
  static const _weekLabels = ['일', '월', '화', '수', '목', '금', '토'];
  static const double _cellExtent = 70;
  static const double _dayAreaHeight = 16;
  static const double _planetMax = 40;
  static const double _planetMin = 15;

  void _showDiaryList(DateTime date, List<DiaryEntry> diaries) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MM월 dd일의 행성들', 'ko_KR').format(date),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListView.separated(
                      shrinkWrap: true,
                      itemCount: diaries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final diary = diaries[index];
                        final planetName = planetBaseNameMap[diary.emotion] ?? 'grey_moon';
                        
                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DiaryDetailScreen(diary: diary),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Image.asset('asset/image/moon_images/$planetName.png', width: 40, height: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(diary.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                      Text(diary.emotion, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.white30),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final diaryByDay = <DateTime, List<DiaryEntry>>{};
    for (final d in widget.diaries) {
      if (d.date.year == _focusedMonth.year && d.date.month == _focusedMonth.month) {
        final key = DateTime(d.date.year, d.date.month, d.date.day);
        diaryByDay.putIfAbsent(key, () => []).add(d);
      }
    }

    final cells = _buildCalendarCells(_focusedMonth);
    final monthTitle = DateFormat('yyyy년 MM월', 'ko_KR').format(_focusedMonth);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthTitle,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: List.generate(7, (i) => Expanded(child: Center(child: Text(_weekLabels[i], style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16))))),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
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
              final dateKey = DateTime(cell.date.year, cell.date.month, cell.date.day);
              final diaries = diaryByDay[dateKey] ?? [];
              final diary = diaries.isNotEmpty ? diaries.first : null;
              final planetName = diary == null ? 'grey_moon' : (planetBaseNameMap[diary.emotion] ?? 'grey_moon');
              final planetSize = (_cellExtent - _dayAreaHeight).clamp(_planetMin, _planetMax);

              return GestureDetector(
                onTap: () {
                  if (diaries.isEmpty) return;
                  if (diaries.length == 1) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DiaryDetailScreen(diary: diaries.first)));
                  } else {
                    _showDiaryList(cell.date, diaries);
                  }
                },
                child: Opacity(
                  opacity: cell.inCurrentMonth ? 1.0 : 0.25,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: Center(
                          child: SizedBox(
                            width: planetSize,
                            height: planetSize,
                            child: Image.asset('asset/image/moon_images/$planetName.png', fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0, right: 0, bottom: 0, height: _dayAreaHeight,
                        child: Center(child: Text('${cell.date.day}', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12))),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<_CalendarCell> _buildCalendarCells(DateTime focusedMonth) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7;
    final prevMonthLastDay = DateTime(focusedMonth.year, focusedMonth.month, 0).day;
    final prevMonth = DateTime(focusedMonth.year, focusedMonth.month - 1, 1);
    final nextMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 1);

    final cells = <_CalendarCell>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(_CalendarCell(date: DateTime(prevMonth.year, prevMonth.month, prevMonthLastDay - (startOffset - 1 - i)), inCurrentMonth: false));
    }
    for (int day = 1; day <= daysInMonth; day++) {
      cells.add(_CalendarCell(date: DateTime(focusedMonth.year, focusedMonth.month, day), inCurrentMonth: true));
    }
    while (cells.length % 7 != 0) {
      final day = cells.length - (startOffset + daysInMonth) + 1;
      cells.add(_CalendarCell(date: DateTime(nextMonth.year, nextMonth.month, day), inCurrentMonth: false));
    }
    return cells;
  }
}

class _CalendarCell {
  final DateTime date;
  final bool inCurrentMonth;
  _CalendarCell({required this.date, required this.inCurrentMonth});
}
