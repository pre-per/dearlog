import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/screens/auth_error_screen.dart';
import '../../core/shared_widgets/elevated_card_container.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../widgets/match_profile_card.dart';

class MatchListScreen extends ConsumerWidget {
  const MatchListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          if (user == null) return AuthErrorScreen();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              children: [
                const SizedBox(height: 15),
                Text(
                  '${user.profile.nickname}님과 어울리는 상대를 찾았어요!',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ElevatedCardContainer(
                  children: [
                    const SizedBox(height: 10),
                    MatchProfileCard(
                      myName: user.profile.nickname,
                      myImage: 'asset/image/kitty.png',
                      partnerName: '솜이',
                      partnerImage: 'asset/image/kitty.png',
                      message: '당신과 솜이는 성향이 잘 맞는 편이에요! 💫',
                    ),
                    const SizedBox(height: 10),
                  ],
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
