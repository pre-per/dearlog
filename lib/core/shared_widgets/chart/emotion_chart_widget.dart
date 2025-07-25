import 'package:dearlog/core/shared_widgets/elevated_card_container.dart';
import 'package:flutter/material.dart';
import 'package:dearlog/core/models/chart/chart_data.dart';
import 'simple_bar_chart.dart';

class EmotionChartWidget extends StatelessWidget {
  const EmotionChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedCardContainer(
          children: [
            SimpleBarChart(
              data: [
                ChartData(label: '행복', count: 15, color: _getColorByLabel('행복')),
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

Color _getColorByLabel(String label) {
  if (label == '행복') {
    return Colors.green;
  } else if (label == '기쁨') {
    return Colors.amber;
  } else if (label == '슬픔') {
    return Colors.deepPurple;
  } else if (label == '불안') {
    return Colors.blueAccent;
  } else if (label == '분노') {
    return Colors.redAccent;
  } else {
    return Colors.grey;
  }
}