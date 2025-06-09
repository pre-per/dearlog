import 'package:flutter/material.dart';
import '../../models/chart/chart_data.dart';

class SimpleBarChart extends StatelessWidget {
  final List<ChartData> data;

  const SimpleBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final int maxCount = data.map((e) => e.count).fold(0, (prev, curr) => curr > prev ? curr : prev);

    return SizedBox(
      height: 180,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: data.map((chartEntry) {
          final double barHeight = maxCount > 0 ? (chartEntry.count / maxCount) * 100 : 0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 🧮 숫자
              Text(
                '${chartEntry.count}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),

              // 📊 막대
              Container(
                width: 28,
                height: barHeight,
                decoration: BoxDecoration(
                  color: chartEntry.color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),

              // 🏷️ 라벨
              Text(
                chartEntry.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}