import 'package:dearlog/core/shared_widgets/tile/simple_title_tile.dart';
import 'package:dearlog/user/providers/user_fetch_providers.dart';
import 'package:dearlog/settings/screens/app_version_screen.dart';
import 'package:dearlog/settings/screens/faq_screen.dart';
import 'package:dearlog/settings/screens/notice_screen.dart';
import 'package:dearlog/settings/screens/notification_setting_screen.dart';
import 'package:dearlog/core/shared_widgets/elevated_card_container.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/screens/login_screen.dart';
import '../../settings/widgets/bottom_modal_sheet/feedback_modal_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void handleLogout(BuildContext context, WidgetRef ref) async {
    try {
      await FirebaseAuth.instance.signOut(); // Firebase 로그아웃
      ref.read(userIdProvider.notifier).state = null; // 상태 초기화
      ref.invalidate(userProvider); // 사용자 정보 캐시 제거

      // 로그인 화면으로 이동
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("로그아웃 실패: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final _feedbackController = TextEditingController();

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: ListView(
              children: [
                _TitleSettingRow(),
                const SizedBox(height: 20),
                ElevatedCardContainer(
                  children: [
                    SimpleTitleTile(
                      title: '내 포인트',
                      trailing: Text(
                        '98점',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueAccent[700],
                        ),
                      ),
                    ),
                    Divider(color: Colors.grey[200]),
                    SimpleTitleTile(
                      title: '자주 묻는 질문',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => FAQScreen()));
                      },
                    ),
                    SimpleTitleTile(title: '고객센터'),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedCardContainer(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      '내 정보',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SimpleTitleTile(title: '내 프로필'),
                    SimpleTitleTile(title: '내 일기장'),
                    SimpleTitleTile(title: '내 매칭 상대'),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedCardContainer(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      '기타 서비스',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SimpleTitleTile(
                      title: '알림 설정',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NotificationSettingScreen(),
                          ),
                        );
                      },
                    ),
                    SimpleTitleTile(
                      title: '공지사항',
                      trailing: Text(
                        '1개',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.greenAccent[700],
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => NoticeScreen()),
                        );
                      },
                    ),
                    SimpleTitleTile(
                      title: '앱 정보',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AppVersionScreen()),
                        );
                      },
                    ),
                    SimpleTitleTile(
                      title: '로그아웃',
                      onTap: () => handleLogout(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _OpinionGiveMe(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      backgroundColor: Colors.white,
                      builder:
                          (context) => FeedbackBottomSheet(
                            controller: _feedbackController,
                            onSubmit: () {
                              final feedback = _feedbackController.text;
                              Navigator.of(context).pop();
                            },
                          ),
                    );
                  },
                ),
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

class _TitleSettingRow extends StatelessWidget {
  const _TitleSettingRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '전체',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(IconsaxPlusBold.setting_2, color: Colors.grey[400]),
        ),
      ],
    );
  }
}

class _OpinionGiveMe extends StatelessWidget {
  final VoidCallback onTap;

  const _OpinionGiveMe({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 100,
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '디어로그에서의 경험은 어떠셨나요?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '솔직한 의견을 들려주세요',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Icon(IconsaxPlusLinear.edit, size: 35),
            ],
          ),
        ),
      ),
    );
  }
}
