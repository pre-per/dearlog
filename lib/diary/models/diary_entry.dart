import 'package:dearlog/app.dart';

class DiaryEntry {
  final String id;
  final DateTime date;
  final String title;
  final String content;
  final String emotion;
  final List<String> imageUrls;
  final String? callId;
  final String? myLetter; // ✅ 추가
  final String? aiComment; // ✅ 추가

  final DiaryAnalysis? analysis;

  DiaryEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    required this.emotion,
    required this.imageUrls,
    this.callId,
    this.myLetter,
    this.aiComment,
    this.analysis,
  });

  DiaryEntry copyWith({
    String? id,
    DateTime? date,
    String? title,
    String? content,
    String? emotion,
    List<String>? imageUrls,
    String? callId,
    String? myLetter,
    String? aiComment,
    DiaryAnalysis? analysis,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      content: content ?? this.content,
      emotion: emotion ?? this.emotion,
      imageUrls: imageUrls ?? List<String>.from(this.imageUrls),
      callId: callId ?? this.callId,
      myLetter: myLetter ?? this.myLetter,
      aiComment: aiComment ?? this.aiComment,
      analysis: analysis ?? this.analysis,
    );
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'],
      date: DateTime.parse(json['date']),
      title: json['title'],
      content: json['content'],
      emotion: json['emotion'],
      imageUrls: List<String>.from(json['imageUrls']),
      callId: json['callId'],
      myLetter: json['myLetter'],
      aiComment: json['aiComment'],
      analysis: json['analysis'] != null
          ? DiaryAnalysis.fromJson(Map<String, dynamic>.from(json['analysis']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'content': content,
      'emotion': emotion,
      'imageUrls': imageUrls,
      if (callId != null) 'callId': callId,
      if (myLetter != null) 'myLetter': myLetter,
      if (aiComment != null) 'aiComment': aiComment,
      if (analysis != null) 'analysis': analysis!.toJson(),
    };
  }
}
