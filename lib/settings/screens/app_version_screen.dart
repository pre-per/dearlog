import 'package:flutter/material.dart';

class AppVersionScreen extends StatelessWidget {
  const AppVersionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              '앱 정보',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 28),
            ),
            const SizedBox(height: 40),
            _VersionGestureDetector(title: '버전 정보 1.0.0', onTap: () {}),
            _VersionGestureDetector(title: '이용약관 & 개인정보 처리방침', onTap: () {})
          ],
        ),
      ),
    );
  }
}

class _VersionGestureDetector extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _VersionGestureDetector({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
        child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),),
      ),
    );
  }
}
