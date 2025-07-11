import 'package:flutter/material.dart';

class RecordButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onTap;

  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? Colors.redAccent : Colors.blueAccent,
          boxShadow: isRecording
              ? [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.6),
              blurRadius: 20,
              spreadRadius: 4,
            )
          ]
              : [],
        ),
        child: const Icon(Icons.mic, size: 36, color: Colors.white),
      ),
    );
  }
}
