import 'package:flutter/material.dart';

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
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // ✅ 10초 후 자동 종료
    Future.delayed(const Duration(seconds: 10), () async {
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(16),
            ),
            constraints: const BoxConstraints(
              maxHeight: 100, // 상단 일부만 사용
              maxWidth: 600,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: AssetImage('asset/image/kitty.png'),
                  backgroundColor: Colors.white,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.callerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        widget.callerSubtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.call_end, color: Colors.red),
                      onPressed: widget.onDecline,
                    ),
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.green),
                      onPressed: widget.onAccept,
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
