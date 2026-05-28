import 'package:dearlog/app.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 글로벌 [incomingCallVisibleProvider] 상태를 토글하는 통화 시작 버튼.
///
/// 배너가 떠 있는 동안에는 시각적으로 흐려지고 탭을 무시한다 — 다이얼로그
/// 중첩(여러 개가 상단에 쌓이는 현상) 방지.
class CallStartIconbutton extends ConsumerWidget {
  const CallStartIconbutton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannerVisible = ref.watch(incomingCallVisibleProvider);

    return GestureDetector(
      onTap: bannerVisible
          ? null
          : () => ref.read(incomingCallVisibleProvider.notifier).state = true,
      child: Opacity(
        opacity: bannerVisible ? 0.45 : 1.0,
        child: Container(
          height: 80,
          width: 80,
          decoration: BoxDecoration(
            color: call_green_color,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: SvgPicture.asset('asset/icons/call/phone_green.svg', width: 35, height: 35),
          ),
        ),
      ),
    );
  }
}
