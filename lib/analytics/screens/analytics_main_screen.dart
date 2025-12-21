import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../auth/screens/auth_error_screen.dart';
import '../../shared_ui/widgets/chart/emotion_chart_widget.dart';
import '../../shared_ui/widgets/elevated_card_container.dart';
import '../../user/providers/user_fetch_providers.dart';

class AnalyticsMainScreen extends ConsumerWidget {
  const AnalyticsMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('분석', style: TextStyle().copyWith(fontSize: 25),),
        centerTitle: false,
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return AuthErrorScreen();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Text('추후 업데이트 예정입니다', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),),
            )
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