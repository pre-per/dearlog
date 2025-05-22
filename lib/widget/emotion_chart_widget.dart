import 'package:flutter/material.dart';

import '../models/emotiondata.dart';
import 'emotion_chart.dart';

class EmotionChartWidget extends StatelessWidget {
  const EmotionChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '  내 감정 그래프',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        EmotionFrequencyBarChart(
          data: [
            EmotionData(label: '행복', count: 15, color: Colors.green),
            EmotionData(label: '기쁨', count: 12, color: Colors.amber),
            EmotionData(label: '슬픔', count: 8, color: Colors.deepPurple),
            EmotionData(label: '불안', count: 5, color: Colors.blueAccent),
            EmotionData(label: '분노', count: 3, color: Colors.redAccent),
          ],
        ),
      ],
    );
  }
}
