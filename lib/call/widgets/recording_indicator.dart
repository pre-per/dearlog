import 'package:flutter/material.dart';

class RecordingIndicator extends StatelessWidget {
  final String currentText;

  const RecordingIndicator({super.key, required this.currentText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.volume_up, size: 20, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                currentText.isEmpty ? '말씀해보세요...' : currentText,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
