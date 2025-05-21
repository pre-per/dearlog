import 'package:dearlog/providers/user_fetch_providers.dart';
import 'package:dearlog/screens/home/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../widget/IncomingCallBanner.dart';
import '../../widget/call_status_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  OverlayEntry? _overlayEntry;

  void _showIncomingCall(BuildContext context) {
    _overlayEntry = OverlayEntry(
      builder:
          (_) => IncomingCallBanner(
            callerName: "디어로그",
            callerSubtitle: "휴대전화",
            onAccept: () {
              _overlayEntry?.remove();
              print("통화 수락");
            },
            onDecline: () {
              _overlayEntry?.remove();
              print("통화 거절");
            },
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Dearlog.', style: TextStyle(fontSize: 25)),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => NotificationScreen()));
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
      body: userProfileAsync.when(
        data: (userProfile) {
          if (userProfile == null) {
            return const Scaffold(
              body: Center(child: Text("사용자 정보를 불러올 수 없습니다.")),
            );
          }
          return ListView(
            children: [
              CallStatusBar(callDays: userProfile.callDays),
              const SizedBox(height: 20),
              IconButton(
                onPressed: () => _showIncomingCall(context),
                icon: const Icon(IconsaxPlusBold.call_calling),
              ),
            ],
          );
        },
        error: (err, _) => Center(child: Text('유저 데이터를 불러오지 못했습니다.\n오류:$err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
