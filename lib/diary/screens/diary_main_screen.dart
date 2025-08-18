import 'package:dearlog/diary/sections/storybook_section_diary.dart';
import 'package:dearlog/diary/widgets/searchbar_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/screens/auth_error_screen.dart';
import '../../user/providers/user_fetch_providers.dart';

class DiaryMainScreen extends ConsumerWidget {
  const DiaryMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          if (user == null) return AuthErrorScreen();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ListView(
              children: [
                const SizedBox(height: 10),
                SearchBarUI(),
                const SizedBox(height: 20),
                StorybookSectionDiary(entries: user.diaries),
                const SizedBox(height: 20),
              ],
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
