import 'package:dearlog/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class IncomingCallBanner extends StatefulWidget {
  final String callerName;
  final String callerSubtitle;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const IncomingCallBanner({
    super.key,
    required this.callerName,
    required this.callerSubtitle,
    this.onAccept,
    this.onDecline,
  });

  @override
  State<IncomingCallBanner> createState() => _IncomingCallBannerState();
}

class _IncomingCallBannerState extends State<IncomingCallBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // ✅ 10초 후 자동 종료
    Future.delayed(const Duration(seconds: 100000), () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) {
        widget.onDecline?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SlideTransition(
        position: _offsetAnimation,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: deep_grey_blue_color,
              borderRadius: BorderRadius.circular(16),
            ),
            constraints: const BoxConstraints(
              maxHeight: 80, // 상단 일부만 사용
              maxWidth: 600,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.callerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        widget.callerSubtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onAccept,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: call_green_color,
                        ),
                        child: Center(
                          child: SvgPicture.asset('asset/icons/call/phone_green.svg', width: 17.5, height: 17.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onDecline,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: call_red_color,
                        ),
                        child: Center(
                          child: SvgPicture.asset('asset/icons/call/phone_red.svg', width: 23.47, height: 23.47),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
