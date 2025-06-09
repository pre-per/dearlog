import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../call/screens/ai_chat_screen.dart';
import '../../core/shared_widgets/elevated_card_container.dart';
import 'IncomingCallBanner.dart';

class CallStarterCard extends ConsumerWidget {
  OverlayEntry? _overlayEntry;

  CallStarterCard();

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
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                ),
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
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showIncomingCall(context),
      child: ElevatedCardContainer(
        backgroundColor: Colors.green[50]!,
        padding: const EdgeInsets.only(bottom: 10, left: 20, right: 20),
        children: [
          Center(
            child: Lottie.asset(
              'asset/lottie/call.json',
              height: 200,
              width: 200,
            ),
          ),
          Container(
            width: double.infinity,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.green,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1), // 그림자 색상 (파스텔톤 그레이 느낌)
                  blurRadius: 10,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '지금 통화하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}