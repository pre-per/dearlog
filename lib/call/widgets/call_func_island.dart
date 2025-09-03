import 'package:flutter/material.dart';

import 'call_func_icon_button.dart';
class CallFuncIsland extends StatelessWidget {
  final VoidCallback onPauseToggle;   // 통화 멈추기/재개
  final VoidCallback onTextToggle;    // 글로 작성 모드 토글
  final VoidCallback onCallEnd;

  const CallFuncIsland({
    super.key,
    required this.onPauseToggle,
    required this.onTextToggle,
    required this.onCallEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CallFuncIconButton(
                iconData: Icons.pause,
                unTappedText: '통화 멈추기',
                tappedText: '통화 다시 시작',
                onTap: onPauseToggle,
              ),
              CallFuncIconButton(
                iconData: Icons.edit_note,
                unTappedText: '글로 작성하기',
                tappedText: '음성 통화하기',
                onTap: onTextToggle,
              ),
            ],
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: onCallEnd,
            child: Container(
              height: 70,
              width: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}
