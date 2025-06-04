import 'package:dearlog/widget/white_card_container.dart';
import 'package:flutter/material.dart';

import '../../models/chart/chart_data.dart';
import 'my_bar_chart.dart';

class EmotionChartWidget extends StatelessWidget {
  const EmotionChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WhiteCardContainer(
          children: [
            MyBarChart(
              data: [
                ChartData(label: '행복', count: 15, color: Colors.green),
                ChartData(label: '기쁨', count: 12, color: Colors.amber),
                ChartData(label: '슬픔', count: 8, color: Colors.deepPurple),
                ChartData(label: '불안', count: 5, color: Colors.blueAccent),
                ChartData(label: '분노', count: 3, color: Colors.redAccent),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ],
    );
  }
}
