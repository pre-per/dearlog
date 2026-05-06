import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자가 자신의 일기를 커뮤니티에 공개한 게시물.
///
/// - `community_posts/{postId}` 최상위 컬렉션에 저장된다.
/// - 이미지는 `community_posts/{postId}/image_*.png` 로 별도 복사되어
///   원본 일기를 삭제해도 살아남는다.
/// - `authorNicknameSnapshot` 은 게시 시점의 닉네임을 동결해서 저장한다 —
///   사용자가 나중에 닉네임을 바꿔도 과거 게시물의 표시 이름은 유지된다.
class CommunityPost {
  final String id;
  final String authorUid;
  final String authorNicknameSnapshot;
  final bool isAnonymous;

  /// 원본 일기 id. 같은 일기는 한 번에 하나의 공개 게시물만 가질 수 있다.
  final String originalDiaryId;

  final String title;
  final String content;
  final String emotion;
  final List<String> imageUrls;

  /// 원본 일기의 작성일 (게시 시점이 아니라 일기 자체의 날짜).
  final DateTime diaryDate;

  /// 커뮤니티 게시 시각.
  final DateTime createdAt;

  final int likeCount;
  final int commentCount;
  final int reportCount;

  const CommunityPost({
    required this.id,
    required this.authorUid,
    required this.authorNicknameSnapshot,
    required this.isAnonymous,
    required this.originalDiaryId,
    required this.title,
    required this.content,
    required this.emotion,
    required this.imageUrls,
    required this.diaryDate,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.reportCount = 0,
  });

  /// UI 표시용 작성자 이름. 익명이면 '익명' 으로 가린다.
  String get displayName => isAnonymous ? '익명' : authorNicknameSnapshot;

  /// 이 게시물이 일기에서 공유된 것인지 — `originalDiaryId` 가 비어있으면
  /// 사용자가 커뮤니티에서 직접 작성한 standalone 게시물.
  bool get isFromDiary => originalDiaryId.trim().isNotEmpty;

  CommunityPost copyWith({
    String? id,
    String? authorUid,
    String? authorNicknameSnapshot,
    bool? isAnonymous,
    String? originalDiaryId,
    String? title,
    String? content,
    String? emotion,
    List<String>? imageUrls,
    DateTime? diaryDate,
    DateTime? createdAt,
    int? likeCount,
    int? commentCount,
    int? reportCount,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      authorUid: authorUid ?? this.authorUid,
      authorNicknameSnapshot:
          authorNicknameSnapshot ?? this.authorNicknameSnapshot,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      originalDiaryId: originalDiaryId ?? this.originalDiaryId,
      title: title ?? this.title,
      content: content ?? this.content,
      emotion: emotion ?? this.emotion,
      imageUrls: imageUrls ?? List<String>.from(this.imageUrls),
      diaryDate: diaryDate ?? this.diaryDate,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      reportCount: reportCount ?? this.reportCount,
    );
  }

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as String,
      authorUid: json['authorUid'] as String,
      authorNicknameSnapshot:
          (json['authorNicknameSnapshot'] as String?) ?? '',
      isAnonymous: (json['isAnonymous'] as bool?) ?? false,
      originalDiaryId: json['originalDiaryId'] as String,
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      emotion: (json['emotion'] as String?) ?? '',
      imageUrls: (json['imageUrls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      diaryDate: _parseDate(json['diaryDate'], 'diaryDate'),
      createdAt: _parseDate(json['createdAt'], 'createdAt'),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorUid': authorUid,
      'authorNicknameSnapshot': authorNicknameSnapshot,
      'isAnonymous': isAnonymous,
      'originalDiaryId': originalDiaryId,
      'title': title,
      'content': content,
      'emotion': emotion,
      'imageUrls': imageUrls,
      'diaryDate': Timestamp.fromDate(diaryDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
      'commentCount': commentCount,
      'reportCount': reportCount,
    };
  }
}

DateTime _parseDate(dynamic value, String fieldName) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  throw FormatException('Invalid date for $fieldName: $value');
}
