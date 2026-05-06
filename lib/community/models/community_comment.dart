import 'package:cloud_firestore/cloud_firestore.dart';

/// 커뮤니티 게시물에 달리는 댓글. MVP 는 플랫(평면) 구조 — 대댓글 없음.
///
/// 저장 위치: `community_posts/{postId}/comments/{commentId}`
class CommunityComment {
  final String id;
  final String postId;
  final String authorUid;
  final String authorNicknameSnapshot;
  final bool isAnonymous;
  final String content;
  final DateTime createdAt;

  /// 수정된 댓글 표시용. 한 번도 수정 안 했으면 null.
  final DateTime? updatedAt;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorUid,
    required this.authorNicknameSnapshot,
    required this.isAnonymous,
    required this.content,
    required this.createdAt,
    this.updatedAt,
  });

  String get displayName => isAnonymous ? '익명' : authorNicknameSnapshot;
  bool get isEdited => updatedAt != null;

  CommunityComment copyWith({
    String? id,
    String? postId,
    String? authorUid,
    String? authorNicknameSnapshot,
    bool? isAnonymous,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorUid: authorUid ?? this.authorUid,
      authorNicknameSnapshot:
          authorNicknameSnapshot ?? this.authorNicknameSnapshot,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      id: json['id'] as String,
      postId: json['postId'] as String,
      authorUid: json['authorUid'] as String,
      authorNicknameSnapshot:
          (json['authorNicknameSnapshot'] as String?) ?? '',
      isAnonymous: (json['isAnonymous'] as bool?) ?? false,
      content: (json['content'] as String?) ?? '',
      createdAt: _parseDate(json['createdAt'], 'createdAt'),
      updatedAt: json['updatedAt'] == null
          ? null
          : _parseDate(json['updatedAt'], 'updatedAt'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'authorUid': authorUid,
      'authorNicknameSnapshot': authorNicknameSnapshot,
      'isAnonymous': isAnonymous,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}

DateTime _parseDate(dynamic value, String fieldName) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  throw FormatException('Invalid date for $fieldName: $value');
}
