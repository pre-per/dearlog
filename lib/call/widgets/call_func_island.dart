import 'dart:io';

import 'package:dearlog/app.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 통화 화면 하단 컨트롤 패널.
/// - 통화 종료 / 일시정지 / 키보드 입력 토글
class CallFuncIsland extends ConsumerWidget {
  final VoidCallback onPauseToggle;
  final VoidCallback onTextToggle;
  final VoidCallback onCallEnd;
  final bool isTextMode;
  final bool isPaused;

  const CallFuncIsland({
    super.key,
    required this.onPauseToggle,
    required this.onTextToggle,
    required this.onCallEnd,
    required this.isTextMode,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0x26ffffff),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: onCallEnd,
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: call_red_color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'asset/icons/call/phone_red.svg',
                      width: 30.52,
                      height: 30.52,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onPauseToggle,
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: isPaused ? call_red_color : Color(0x1affffff),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'asset/icons/call/pause.svg',
                      width: 20,
                      height: 20,
                      color: isPaused ? Colors.red : Colors.white,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onTextToggle,
                child: Container(
                  height: 52,
                  width: 150,
                  decoration: BoxDecoration(
                    color: isTextMode ? call_green_color : Color(0x1affffff),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'asset/icons/call/keyboard.svg',
                        width: 20,
                        height: 20,
                        color: isTextMode ? Colors.green[200] : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isTextMode ? '음성 모드' : '키보드 입력',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isTextMode ? Colors.green[200] : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (Platform.isIOS)
            Center(
              child: Text(
                '*주의* 무음모드를 해제하고 사용하세요',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
