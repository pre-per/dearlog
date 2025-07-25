import 'package:flutter/material.dart';

import 'call_func_icon_button.dart';

class CallFuncIsland extends StatelessWidget {
  final VoidCallback onTap1;
  final VoidCallback onTap2;
  final VoidCallback onTap3;
  final VoidCallback onCallEnd;

  const CallFuncIsland({
    super.key,
    required this.onTap1,
    required this.onTap2,
    required this.onTap3,
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
                onTap: onTap1,
              ),
              CallFuncIconButton(
                iconData: Icons.edit_note,
                unTappedText: '글로 작성하기',
                tappedText: '음성 통화하기',
                onTap: onTap2,
              ),
              CallFuncIconButton(
                iconData: Icons.mic,
                unTappedText: '녹음하기',
                tappedText: '녹음 중지하기',
                onTap: onTap3,
              ),
            ],
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: onCallEnd,
            child: Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: Icon(Icons.call_end, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}
