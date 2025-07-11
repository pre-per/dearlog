import 'package:flutter/material.dart';
import '../widgets/call_starter_card.dart';

class CallStarterSection extends StatelessWidget {
  const CallStarterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 25, bottom: 15),
          child: Text(
            '오늘 하루 이야기해볼까요?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        CallStarterCard(),
      ],
    );
  }
}