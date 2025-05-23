import 'package:flutter/material.dart';

import '../../models/chart/chart_data.dart';
import 'my_bar_chart.dart';

class InterestChartWidget extends StatelessWidget {
  const InterestChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '  나의 흥미',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        MyBarChart(
          data: [
            ChartData(label: '행복', count: 15, color: Colors.green),
            ChartData(label: '기쁨', count: 12, color: Colors.amber),
            ChartData(label: '슬픔', count: 8, color: Colors.deepPurple),
            ChartData(label: '불안', count: 5, color: Colors.blueAccent),
            ChartData(label: '분노', count: 3, color: Colors.redAccent),
          ],
        ),
      ],
    );
  }
}
