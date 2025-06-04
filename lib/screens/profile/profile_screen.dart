import 'package:dearlog/providers/user/user_fetch_providers.dart';
import 'package:dearlog/screens/profile/app_version_screen.dart';
import 'package:dearlog/screens/profile/faq_screen.dart';
import 'package:dearlog/screens/profile/notice_screen.dart';
import 'package:dearlog/screens/profile/notification_setting_screen.dart';
import 'package:dearlog/widget/bottom_sheet/feedback_bottomsheet.dart';
import 'package:dearlog/widget/tile/setting_menu_tile.dart';
import 'package:dearlog/widget/white_card_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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
                _titleSettingRow(),
                const SizedBox(height: 20),
                WhiteCardContainer(
                  children: [
                    SettingMenuTile(
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
                    SettingMenuTile(
                      title: '자주 묻는 질문',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => FAQScreen()));
                      },
                    ),
                    SettingMenuTile(title: '고객센터'),
                  ],
                ),
                const SizedBox(height: 20),
                WhiteCardContainer(
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
                    SettingMenuTile(title: '내 프로필'),
                    SettingMenuTile(title: '내 일기장'),
                    SettingMenuTile(title: '내 매칭 상대'),
                  ],
                ),
                const SizedBox(height: 20),
                WhiteCardContainer(
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
                    SettingMenuTile(
                      title: '알림 설정',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NotificationSettingScreen(),
                          ),
                        );
                      },
                    ),
                    SettingMenuTile(
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
                    SettingMenuTile(
                      title: '앱 정보',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AppVersionScreen()),
                        );
                      },
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

class _titleSettingRow extends StatelessWidget {
  const _titleSettingRow({super.key});

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

class _ProfileDoubleButtonRow extends StatelessWidget {
  final String buttonName1;
  final String buttonName2;
  final VoidCallback? onTap1;
  final VoidCallback? onTap2;

  const _ProfileDoubleButtonRow({
    required this.buttonName1,
    required this.buttonName2,
    required this.onTap1,
    required this.onTap2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: InkWell(
            onTap: onTap1,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: Text(
                  buttonName1,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: InkWell(
            onTap: onTap2,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: Text(
                  buttonName2,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
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
