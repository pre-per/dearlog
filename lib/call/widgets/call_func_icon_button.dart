import 'package:flutter/material.dart';

class CallFuncIconButton extends StatefulWidget {
  final String tappedText;
  final String unTappedText;
  final IconData iconData;
  final VoidCallback? onTap;

  const CallFuncIconButton({
    super.key,
    this.onTap,
    required this.iconData,
    required this.tappedText,
    required this.unTappedText,
  });

  @override
  State<CallFuncIconButton> createState() => _CallFuncIconButtonState();
}

class _CallFuncIconButtonState extends State<CallFuncIconButton> {
  bool isTapped = false;

  void _handleTap() {
    setState(() {
      isTapped = !isTapped;
    });
    widget.onTap?.call(); // onTap이 null이 아닐 때만 호출
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        height: 100,
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              widget.iconData,
              color: isTapped ? Colors.green : Colors.black,
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              isTapped ? widget.tappedText : widget.unTappedText,
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
