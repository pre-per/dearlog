import 'package:flutter/material.dart';

class MatchProfileCard extends StatelessWidget {
  final String myName;
  final String myImage;
  final String partnerName;
  final String partnerImage;
  final String message;

  const MatchProfileCard({
    super.key,
    required this.myName,
    required this.myImage,
    required this.partnerName,
    required this.partnerImage,
    this.message = '서로 잘 어울리는 상대에요!',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      color: Colors.white,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 👤 프로필들
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildProfile(myName, myImage),
                Column(
                  children: const [
                    Icon(Icons.favorite, color: Colors.pinkAccent, size: 32),
                    SizedBox(height: 4),
                    Text(
                      '♥',
                      style: TextStyle(fontSize: 14, color: Colors.pinkAccent),
                    )
                  ],
                ),
                _buildProfile(partnerName, partnerImage),
              ],
            ),
            const SizedBox(height: 20),

            // 💌 메시지
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile(String name, String imagePath) {
    return Column(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundImage: AssetImage(imagePath), // 또는 NetworkImage
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
