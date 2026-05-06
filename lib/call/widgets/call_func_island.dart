import 'dart:io';

import 'package:dearlog/app.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 통화 화면 하단 컨트롤 패널.
/// - 통화 종료 / 일시정지 / 키보드 입력 토글
/// - 그림일기 자동 생성 토글 (illustrationEnabledProvider 연동, 기본 ON)
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
    final illustrationEnabled = ref.watch(illustrationEnabledProvider);

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
                  width: 92,
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
                      const SizedBox(width: 6),
                      Text(
                        isTextMode ? '해제' : '입력',
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
              _IllustrationToggleButton(
                enabled: illustrationEnabled,
                onTap: () =>
                    ref.read(illustrationEnabledProvider.notifier).toggle(),
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

/// 그림일기 자동 생성 토글 버튼.
/// ON: 금색 글로우 + 채워진 톤. OFF: 무채색 글래스 톤.
class _IllustrationToggleButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _IllustrationToggleButton({
    required this.enabled,
    required this.onTap,
  });

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 52,
        width: 92,
        decoration: BoxDecoration(
          color: enabled
              ? _gold.withOpacity(0.22)
              : const Color(0x1affffff),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled
                ? _gold.withOpacity(0.55)
                : Colors.transparent,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _gold.withOpacity(0.25),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              enabled ? Icons.auto_awesome : Icons.auto_awesome_outlined,
              size: 18,
              color: enabled ? _gold : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              '그림',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: enabled ? _gold : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
