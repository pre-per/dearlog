import 'package:flutter/material.dart';
import 'package:dearlog/app.dart';

class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      appBar: AppBar(
        title: Text('공지사항'),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Center(
          child: const Text(
            '공지사항이 없습니다',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
          ),
        )
      ),
    );
  }
}
