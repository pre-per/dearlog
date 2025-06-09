class Match {
  final String matchId;
  final String targetUserId;
  final double matchScore;
  final String reason;
  final String status; // "pending", "accepted", "rejected"
  final DateTime createdAt;

  Match({
    required this.matchId,
    required this.targetUserId,
    required this.matchScore,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      matchId: json['matchId'],
      targetUserId: json['targetUserId'],
      matchScore: json['matchScore'].toDouble(),
      reason: json['reason'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'targetUserId': targetUserId,
      'matchScore': matchScore,
      'reason': reason,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
