import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottiePopupDialog extends StatelessWidget {
  final String lottieAsset;           // 🎉 상단 애니메이션 (Lottie)
  final String messageText;          // 메시지 ("1포인트 받기 완료!")
  final String confirmButtonText;    // 첫 번째 버튼 텍스트
  final VoidCallback onConfirm;

  const LottiePopupDialog({
    super.key,
    required this.lottieAsset,
    required this.messageText,
    this.confirmButtonText = '확인',
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ✅ 배경 흐리기 (blur)
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            color: Colors.black.withOpacity(0.3), // 약간 어둡게
          ),
        ),

        // 📦 Dialog
        Center(
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🎞 Lottie 애니메이션
                  Lottie.asset(
                    lottieAsset,
                    height: 150,
                    repeat: false,
                  ),
                  const SizedBox(height: 40),

                  // 📘 메시지
                  Text(
                    messageText,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // 버튼들
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            confirmButtonText,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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
