import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자가 받은 알림의 영구 기록. 보관함 화면에 노출된다.
///
/// 저장 위치: `users/{uid}/notifications/{notifId}`
/// v1 은 `type == 'comment'` (커뮤니티 댓글) 만 적재된다 — 일일 리마인더/편지 같은
/// 로컬 알림은 발화 시점 콜백이 안정적이지 않아 v2 에서 추가.
class NotificationRecord {
  final String id;

  /// 'comment' (v1). 향후 'letter', 'daily_reminder' 등 추가될 수 있음.
  final String type;

  /// 알림 제목 (예: "박지원 님이 댓글을 남겼어요").
  final String title;

  /// 알림 본문 미리보기 (예: 댓글 본문 80자 컷).
  final String body;

  /// `NotificationPayload` 규약을 따르는 라우팅 키 (예: `comment:{postId}`).
  final String payload;

  final DateTime createdAt;
  final bool read;

  /// 메타 — 미리보기에 활용. comment 타입 한정.
  final String? postId;
  final String? postTitle;
  final String? senderName;

  const NotificationRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.payload,
    required this.createdAt,
    required this.read,
    this.postId,
    this.postTitle,
    this.senderName,
  });

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      id: json['id'] as String,
      type: (json['type'] as String?) ?? 'comment',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      payload: (json['payload'] as String?) ?? '',
      createdAt: _parseDate(json['createdAt']),
      read: (json['read'] as bool?) ?? false,
      postId: json['postId'] as String?,
      postTitle: json['postTitle'] as String?,
      senderName: json['senderName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'payload': payload,
        'createdAt': Timestamp.fromDate(createdAt),
        'read': read,
        if (postId != null) 'postId': postId,
        if (postTitle != null) 'postTitle': postTitle,
        if (senderName != null) 'senderName': senderName,
      };
}

DateTime _parseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.parse(v);
  // serverTimestamp 가 아직 반영 안 된 경우 (writePending) — 현재 시각으로 fallback.
  return DateTime.now();
}
