class DiaryEntry {
  final String id; // 고유 ID (UUID 권장)
  final DateTime date; // 일기 날짜 (사용자가 선택한 날짜)
  final String title;
  final String content;
  final String emotion; // "happy", "sad", "angry" 등 감정 코드
  final List<String> imageUrls; // 이미지 경로 (클라우드 저장소 경로 등)

  DiaryEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    required this.emotion,
    required this.imageUrls,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'],
      date: DateTime.parse(json['date']),
      title: json['title'],
      content: json['content'],
      emotion: json['emotion'],
      imageUrls: List<String>.from(json['imageUrls']),
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
    };
  }
}
