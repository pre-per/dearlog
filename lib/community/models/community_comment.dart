import 'package:cloud_firestore/cloud_firestore.dart';

/// 커뮤니티 게시물에 달리는 댓글.
///
/// 저장 위치: `community_posts/{postId}/comments/{commentId}`
///
/// 들여쓰기는 항상 1단계로 평면화된다 — [parentCommentId] 가 null 이면 최상위
/// 댓글, non-null 이면 그 최상위 댓글 아래 답글로 표시된다. "답글의 답글" 도
/// 데이터상으로는 같은 최상위 댓글을 가리키며 (즉 grandparent 아닌 root 를 가리킴)
/// 화면에서는 동일 들여쓰기 줄에 시간순으로 늘어선다. @멘션 텍스트가 즉시
/// 응답 대상을 알려주는 역할을 한다.
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

  /// 부모 댓글 id. null = 최상위 댓글, 있으면 그 댓글에 달린 답글.
  final String? parentCommentId;

  /// 답글이 가리키는 부모 댓글의 표시 이름(게시 시점 동결). 부모가 삭제되거나
  /// 익명이어도 "@xxx" 멘션 표시를 유지하기 위해 답글에 함께 저장한다.
  /// 최상위 댓글이면 null.
  final String? parentNicknameSnapshot;

  /// 익명 댓글일 때도 작성자의 랭크/글로우를 노출할지 — 작성 시점의 user
  /// preference 를 동결. 비익명 댓글은 항상 노출되므로 이 필드는 무시된다.
  final bool showRankIfAnonymous;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorUid,
    required this.authorNicknameSnapshot,
    required this.isAnonymous,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.parentCommentId,
    this.parentNicknameSnapshot,
    this.showRankIfAnonymous = false,
  });

  String get displayName => isAnonymous ? '익명' : authorNicknameSnapshot;
  bool get isEdited => updatedAt != null;
  bool get isReply => parentCommentId != null;

  CommunityComment copyWith({
    String? id,
    String? postId,
    String? authorUid,
    String? authorNicknameSnapshot,
    bool? isAnonymous,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? parentCommentId,
    String? parentNicknameSnapshot,
    bool? showRankIfAnonymous,
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
      parentCommentId: parentCommentId ?? this.parentCommentId,
      parentNicknameSnapshot:
          parentNicknameSnapshot ?? this.parentNicknameSnapshot,
      showRankIfAnonymous: showRankIfAnonymous ?? this.showRankIfAnonymous,
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
      parentCommentId: json['parentCommentId'] as String?,
      parentNicknameSnapshot: json['parentNicknameSnapshot'] as String?,
      showRankIfAnonymous: (json['showRankIfAnonymous'] as bool?) ?? false,
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
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
      if (parentNicknameSnapshot != null)
        'parentNicknameSnapshot': parentNicknameSnapshot,
      'showRankIfAnonymous': showRankIfAnonymous,
    };
  }
}

DateTime _parseDate(dynamic value, String fieldName) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  throw FormatException('Invalid date for $fieldName: $value');
}
