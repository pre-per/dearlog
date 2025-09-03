import 'package:dearlog/diary/providers/diary_providers.dart';
import 'package:dearlog/diary/sections/storybook_section_diary.dart';
import 'package:dearlog/shared_ui/widgets/searchbar_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/screens/auth_error_screen.dart';
import '../../user/providers/user_fetch_providers.dart';

class DiaryMainScreen extends ConsumerWidget {
  const DiaryMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync   = ref.watch(userProvider);
    final diariesAsync = ref.watch(filteredDiaryListProvider); // ⬅️ 변경

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          if (user == null) return const AuthErrorScreen();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ListView(
              children: [
                const SizedBox(height: 10),
                const SearchBarUI(),
                const SizedBox(height: 20),
                diariesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('일기를 불러오는 중 오류가 발생했어요.\n$e'),
                  ),
                  data: (diaries) => StorybookSectionDiary(entries: diaries),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
        error: (err, _) => Center(
          child: Text('사용자 정보를 불러올 수 없습니다\n오류:$err', softWrap: true),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
