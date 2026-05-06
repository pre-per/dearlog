import 'package:cloud_firestore/cloud_firestore.dart';

/// 신고 대상 유형. MVP 는 게시물/댓글 두 가지.
enum ReportTargetType { post, comment }

/// 부적절한 게시물/댓글 신고. 저장 위치: `community_reports/{reportId}` (최상위).
///
/// MVP 에서는 자동 처리 없이 누적만 하고, 운영자가 콘솔에서 수동 검토한다.
class CommunityReport {
  final String id;
  final String reporterUid;
  final ReportTargetType targetType;
  final String targetId;

  /// 댓글 신고일 때 어떤 게시물에 달린 댓글인지 알기 위해 같이 저장.
  /// 게시물 신고일 때는 `targetId` 와 동일하다.
  final String postId;

  final String reason;
  final DateTime createdAt;

  /// 'pending' | 'resolved' | 'dismissed' — 운영자가 갱신.
  final String status;

  const CommunityReport({
    required this.id,
    required this.reporterUid,
    required this.targetType,
    required this.targetId,
    required this.postId,
    required this.reason,
    required this.createdAt,
    this.status = 'pending',
  });

  factory CommunityReport.fromJson(Map<String, dynamic> json) {
    return CommunityReport(
      id: json['id'] as String,
      reporterUid: json['reporterUid'] as String,
      targetType: _parseType(json['targetType']),
      targetId: json['targetId'] as String,
      postId: json['postId'] as String,
      reason: (json['reason'] as String?) ?? '',
      createdAt: _parseDate(json['createdAt'], 'createdAt'),
      status: (json['status'] as String?) ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporterUid': reporterUid,
      'targetType': targetType.name,
      'targetId': targetId,
      'postId': postId,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }
}

ReportTargetType _parseType(dynamic value) {
  if (value is String) {
    return ReportTargetType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => ReportTargetType.post,
    );
  }
  return ReportTargetType.post;
}

DateTime _parseDate(dynamic value, String fieldName) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  throw FormatException('Invalid date for $fieldName: $value');
}
