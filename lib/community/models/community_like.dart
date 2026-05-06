import 'package:cloud_firestore/cloud_firestore.dart';

/// 좋아요 1건. 저장 위치: `community_posts/{postId}/likes/{userId}`
///
/// 문서 id 가 곧 사용자 uid 이므로, 한 사용자는 한 게시물에 하나의 좋아요만
/// 가질 수 있다 (토글 동작에 자연스럽게 맞다).
class CommunityLike {
  final String userId;
  final DateTime createdAt;

  const CommunityLike({required this.userId, required this.createdAt});

  factory CommunityLike.fromJson(Map<String, dynamic> json) {
    return CommunityLike(
      userId: json['userId'] as String,
      createdAt: _parseDate(json['createdAt'], 'createdAt'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

DateTime _parseDate(dynamic value, String fieldName) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  throw FormatException('Invalid date for $fieldName: $value');
}
