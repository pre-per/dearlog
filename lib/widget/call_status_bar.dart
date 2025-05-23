import 'package:flutter/material.dart';

import '../models/conversation/call_day.dart';

class CallStatusBar extends StatefulWidget {
  final List<CallDay> callDays;

  const CallStatusBar({super.key, required this.callDays});

  @override
  State<CallStatusBar> createState() => _CallStatusBarState();
}

class _CallStatusBarState extends State<CallStatusBar> {
  late List<CallDay> _days;

  @override
  void initState() {
    super.initState();
    _days = widget.callDays;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Container(
      color: Colors.grey[100],
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _days.length,
        separatorBuilder: (context, index) {
          final isToday = _isSameDate(_days[index].date, today);
          return isToday
              ? const VerticalDivider(
            width: 24,
            thickness: 1,
            indent: 10,
            endIndent: 10,
            color: Colors.black26,
          )
              : const SizedBox(width: 24);
        },
        itemBuilder: (context, index) {
          final day = _days[index];

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day.formattedDate,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _days[index] = CallDay(
                      date: day.date,
                      called: !day.called,
                    );
                  });
                },
                borderRadius: BorderRadius.circular(100),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: day.called ? Colors.green : Colors.white,
                  child: Icon(
                    Icons.call,
                    color: day.called ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

