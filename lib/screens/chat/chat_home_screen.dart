import 'package:dearlog/screens/chat/ai_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../providers/user_fetch_providers.dart';
import '../../widget/IncomingCallBanner.dart';
import '../../widget/call_status_bar.dart';

class ChatHomeScreen extends ConsumerStatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  ConsumerState createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends ConsumerState<ChatHomeScreen> {
  OverlayEntry? _overlayEntry;

  void _showIncomingCall(BuildContext context) {
    _overlayEntry = OverlayEntry(
      builder:
          (_) => IncomingCallBanner(
            callerName: "디어로그",
            callerSubtitle: "휴대전화",
            onAccept: () {
              _overlayEntry?.remove();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => AiChatScreen()));
            },
            onDecline: () {
              _overlayEntry?.remove();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    '시간 날 때 다시 걸어주세요! :)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                  ),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.grey[600],
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      body: userProfileAsync.when(
        data: (userProfile) {
          if (userProfile == null) {
            return const Scaffold(
              body: Center(child: Text("사용자 정보를 불러올 수 없습니다.")),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              children: [
                const SizedBox(height: 40),
                Text(
                  '디어로그와 통화하기',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 25),
                ),
                const SizedBox(height: 30),
                CallStatusBar(callDays: userProfile.callDays),
                const SizedBox(height: 200),
                IconButton(
                  onPressed: () => _showIncomingCall(context),
                  icon: const Icon(IconsaxPlusBold.call_calling, size: 100),
                ),
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
