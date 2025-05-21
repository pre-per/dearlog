import 'package:dearlog/providers/user_fetch_providers.dart';
import 'package:dearlog/screens/profile/faq_screen.dart';
import 'package:dearlog/widget/feedback_bottomsheet.dart';
import 'package:dearlog/widget/setting_menu_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final _feedbackController = TextEditingController();

    return Scaffold(
      body: userProfileAsync.when(
        data: (user) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              children: [
                const SizedBox(height: 40),
                const Text(
                  '마이페이지',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 40),
                _ProfileDoubleButtonRow(
                  buttonName1: '채팅 문의',
                  buttonName2: '자주 묻는 질문',
                  onTap1: () {},
                  onTap2: () {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => FAQScreen()));
                  },
                ),
                const SizedBox(height: 40),
                SettingMenuTile(title: '내 정보'),
                Divider(color: Colors.grey[300], indent: 15, endIndent: 15),
                SettingMenuTile(title: '알림 설정'),
                SettingMenuTile(
                  title: '공지사항',
                  trailing: Text(
                    '1개',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.greenAccent[700],
                    ),
                  ),
                ),
                SettingMenuTile(title: '앱 정보'),
                const SizedBox(height: 30),
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
                    fontSize: 18,
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
                    fontSize: 18,
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
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.grey, width: 1),
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
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '솔직한 의견을 들려주세요',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
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
