import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SubscriptionDialog extends StatefulWidget {
  final void Function(String selectedPlan) onConfirm;

  const SubscriptionDialog({super.key, required this.onConfirm});

  @override
  State<SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<SubscriptionDialog> {
  String _selected = '1개월';

  final List<Map<String, String>> _plans = [
    {'label': '1개월', 'price': '₩3,900'},
    {'label': '3개월', 'price': '₩9,900'},
    {'label': '12개월', 'price': '₩29,900'},
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🔲 Blur 배경
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),

        // 💬 Dialog
        Center(
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '디어로그 프로모션',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // 🎞 공간 확보 for Lottie
                  Lottie.asset('asset/lottie/gift.json'),

                  // 여기 Lottie.asset(...) 넣으면 됨
                  const SizedBox(height: 20),

                  // 📦 플랜 목록
                  ..._plans.map((plan) {
                    final selected = _selected == plan['label'];
                    return GestureDetector(
                      onTap: () => setState(() => _selected = plan['label']!),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? Colors.green[50] : Colors.grey[50],
                          border: Border.all(
                            color:
                                selected ? Colors.green : Colors.grey.shade300,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              plan['label']!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    selected ? Colors.black : Colors.grey[700],
                              ),
                            ),
                            Text(
                              plan['price']!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    selected ? Colors.black : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 30),

                  // ⬇️ 수직 버튼 배치
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          widget.onConfirm(_selected);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '지금 가입하기',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: SizedBox(
                          height: 30,
                          child: Center(
                            child: Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
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
      ],
    );
  }
}
