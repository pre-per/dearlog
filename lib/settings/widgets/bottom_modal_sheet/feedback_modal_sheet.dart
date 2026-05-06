import 'package:flutter/material.dart';

class FeedbackBottomSheet extends StatefulWidget {
  final VoidCallback? onSubmit;
  final TextEditingController controller;

  const FeedbackBottomSheet({
    super.key,
    required this.controller,
    this.onSubmit,
  });

  @override
  State<FeedbackBottomSheet> createState() => _FeedbackBottomSheetState();
}

class _FeedbackBottomSheetState extends State<FeedbackBottomSheet> {
  late bool isTextNotEmpty;

  static const _gold = Color(0xFFFFD964);

  @override
  void initState() {
    super.initState();
    isTextNotEmpty = widget.controller.text.trim().isNotEmpty;

    widget.controller.addListener(() {
      final isNowNotEmpty = widget.controller.text.trim().isNotEmpty;
      if (isNowNotEmpty != isTextNotEmpty) {
        setState(() {
          isTextNotEmpty = isNowNotEmpty;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '디어로그에서\n경험은 어떠셨나요?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFamily: 'GowunBatang',
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '남겨주신 의견은 서비스 개선에 소중히 활용할게요.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
              fontFamily: 'GowunBatang',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: widget.controller,
              maxLines: 5,
              cursorColor: _gold,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'GowunBatang',
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: '솔직한 이야기를 들려주세요.',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontFamily: 'GowunBatang',
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: isTextNotEmpty ? widget.onSubmit : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: isTextNotEmpty
                    ? _gold.withOpacity(0.18)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isTextNotEmpty
                      ? _gold.withOpacity(0.5)
                      : Colors.white.withOpacity(0.10),
                ),
              ),
              child: Center(
                child: Text(
                  '의견 남기기',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isTextNotEmpty
                        ? _gold
                        : Colors.white.withOpacity(0.35),
                    fontFamily: 'GowunBatang',
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
