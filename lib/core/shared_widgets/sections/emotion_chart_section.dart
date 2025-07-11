import 'package:flutter/material.dart';

import '../../../call/models/conversation/call_day.dart';
import '../chart/emotion_chart_widget.dart';


class EmotionChartSection extends StatelessWidget {
  final List<CallDay> callDays;

  const EmotionChartSection({super.key, required this.callDays});

  @override
  Widget build(BuildContext context) {
    if (callDays.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 50, bottom: 10),
          child: Text(
            '최근 감정 그래프',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        EmotionChartWidget(callDays: callDays),
      ],
    );
  }
}