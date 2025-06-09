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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 10),
          const Text(
            '디어로그에서\n경험은 어떠셨나요?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '남겨주신 의견은 서비스 개선에 소중히 활용하겠습니다.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: widget.controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '솔직한 이야기를 들려주세요.',
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: isTextNotEmpty ? widget.onSubmit : null,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: isTextNotEmpty
                      ? Colors.deepPurpleAccent[100]
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '의견 남기기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: isTextNotEmpty
                          ? Colors.black
                          : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 25),
        ],
      ),
    );
  }
}
