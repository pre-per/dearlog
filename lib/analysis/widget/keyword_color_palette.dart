import 'package:flutter/material.dart';

const Color _pastelBlue = Color(0xFF8FB6FF);
const Color _pastelGreen = Color(0xFF9BE5B6);
const Color _pastelOrange = Color(0xFFFFB37A);
const Color _pastelPink = Color(0xFFFFA8C9);
const Color _pastelPurple = Color(0xFFC9A8FF);
const Color _pastelGrey = Color(0xFFB8C0CC);

const Map<String, Color> _emotionColor = {
  '슬픔': _pastelBlue,
  '외로움': _pastelBlue,
  '우울': _pastelBlue,
  '평온': _pastelGreen,
  '안정': _pastelGreen,
  '차분': _pastelGreen,
  '분노': _pastelOrange,
  '짜증': _pastelOrange,
  '답답함': _pastelOrange,
  '기쁨': _pastelPink,
  '설렘': _pastelPink,
  '즐거움': _pastelPink,
  '행복': _pastelPurple,
  '만족': _pastelPurple,
  '감사': _pastelPurple,
};

Color keywordGlowColor(String emotion) =>
    _emotionColor[emotion] ?? _pastelGrey;
