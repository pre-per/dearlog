import 'package:dearlog/auth/screens/auth_error_screen.dart';
import 'package:dearlog/diary/providers/diary_providers.dart';
import 'package:dearlog/user/providers/user_fetch_providers.dart';
import 'package:dearlog/settings/screens/sub_screens/notice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../main.dart';
import '../../home/sections/index.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final diaryAsync = ref.watch(diaryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
              (Route<dynamic> route) => false,
            );
          },
          child: Image.asset('asset/image/logo.png', width: 120, height: 120),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => NoticeScreen()));
            },
            icon: Icon(
              IconsaxPlusBold.notification,
              color: Colors.grey[400],
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
        ],
      ),

      body: userAsync.when(
        data: (user) {
          if (user == null) return AuthErrorScreen();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              children: [
                CallStarterSection(),

                diaryAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('일기를 불러오는 중 오류가 발생했어요.\n$e'),
                  ),
                  data: (diaries) => StorybookSection(diaries: diaries),
                ),

                AdditionalServiceSection(ref: ref),
              ],
            ),
          );
        },
        error: (err, _) => Center(child: Text('유저 데이터를 불러오지 못했습니다.\n오류:$err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
