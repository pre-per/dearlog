import 'package:dearlog/app.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CallStartIconbutton extends StatelessWidget {
  OverlayEntry? _overlayEntry;

  CallStartIconbutton({super.key});

  void _showIncomingCall(BuildContext context) {
    _overlayEntry = OverlayEntry(
      builder:
          (_) => IncomingCallBanner(
            callerName: "디어로그",
            callerSubtitle: "휴대전화",
            onAccept: () {
              _overlayEntry?.remove();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => AiChatScreen()));
            },
            onDecline: () {
              _overlayEntry?.remove();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    '시간 날 때 다시 걸어주세요! :)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.grey[600],
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showIncomingCall(context),
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
    );
  }
}
