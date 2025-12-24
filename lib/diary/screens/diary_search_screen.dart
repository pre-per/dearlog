import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:dearlog/app.dart';

class DiarySearchScreen extends ConsumerWidget {
  const DiarySearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diariesAsync = ref.watch(filteredDiaryListProvider);
    final query = ref.watch(searchQueryProvider);

    return BaseScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            ref.read(searchQueryProvider.notifier).state = '';
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.transparent,
      ),
      body: diariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (diaries) {
          // ✅ query로 필터링
          final results =
              diaries.where((d) {
                // DiaryEntry 필드명은 네 프로젝트에 맞춰서 조정 가능
                // (예: d.title, d.content가 실제로 없으면 d.summary 등으로)
                return entryMatchesQuery(
                  queryRaw: query,
                  title: (d.title ?? ''), // ✅ 프로젝트 필드명에 맞게 수정!
                  content: (d.content ?? ''), // ✅ 프로젝트 필드명에 맞게 수정!
                  date: d.date,
                  emotion: d.emotion,
                );
              }).toList();

          return Column(
            children: [
              const SizedBox(height: 12),
              const SearchBarUI(),
              const SizedBox(height: 12),

              Expanded(
                child:
                    results.isEmpty
                        ? Center(
                          child: Text(
                            query.trim().isEmpty
                                ? '검색어를 입력해 일기를 찾아보세요'
                                : '검색 결과가 없어요',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: results.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final diary = results[index];

                            return _SearchResultTile(
                              diary: diary,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => DiaryDetailScreen(diary: diary),
                                  ),
                                );
                              },
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final DiaryEntry diary;
  final VoidCallback onTap;

  const _SearchResultTile({required this.diary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final preview = (diary.content ?? '').trim();
    final shortPreview =
        preview.length > 70 ? '${preview.substring(0, 70)}…' : preview;

    // ✅ 행성
    final planetName = planetBaseNameMap[diary.emotion] ?? 'grey_moon';

    // ✅ 오늘 여부
    final now = DateTime.now();
    final isToday =
        now.year == diary.date.year &&
        now.month == diary.date.month &&
        now.day == diary.date.day;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Color(0x1affffff),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // =====================
                // 왼쪽: 행성 + 날짜
                // =====================
                SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipOval(
                              child: Image.asset(
                                'asset/image/moon_images/$planetName.png',
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                              ),
                            ),

                            // ⭐ 오늘 표시
                            if (isToday)
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.35),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        DateFormat('MM/dd', 'ko_KR').format(diary.date),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.80),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('EEEE', 'ko_KR').format(diary.date),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.80),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // =====================
                // 오른쪽: 텍스트 영역
                // =====================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목
                      Text(
                        diary.title ?? '제목 없음',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // 미리보기
                      Text(
                        shortPreview.isEmpty ? '내용 없음' : shortPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[350],
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 감정 태그 + 요일
                      Row(
                        children: [
                          // 감정 태그
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              diary.emotion, // 예: 행복 / 우울 / 평온
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
