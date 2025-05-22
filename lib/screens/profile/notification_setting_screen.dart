import 'package:flutter/material.dart';

class NotificationSettingScreen extends StatelessWidget {
  const NotificationSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: ListView(
          children: [
            const SizedBox(height: 20),
            const Text(
              '알림 설정',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 28),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
