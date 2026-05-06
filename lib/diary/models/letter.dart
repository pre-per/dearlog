/// 일기에 첨부되는 "내게 보내는 편지" 모델.
///
/// 라이프사이클:
/// - draft   : 작성 중. sentAt == null
/// - locked  : 보냈고 아직 잠금 해제 시각이 안 됨. sentAt != null && unlockAt > now
/// - unlocked: 잠금 해제됨. sentAt != null && unlockAt <= now (또는 unlockAt == null)
class Letter {
  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? unlockAt;

  Letter({
    required this.id,
    required this.content,
    required this.createdAt,
    this.sentAt,
    this.unlockAt,
  });

  bool get isDraft => sentAt == null;

  bool get isLocked {
    if (sentAt == null || unlockAt == null) return false;
    return DateTime.now().isBefore(unlockAt!);
  }

  bool get isUnlocked {
    if (sentAt == null) return false;
    if (unlockAt == null) return true;
    return !DateTime.now().isBefore(unlockAt!);
  }

  /// 잠금 해제까지 남은 일수 (locked 상태 한정)
  /// 자정 기준 차이를 사용해 "오늘 저녁 도착"이 D-0이 되도록 함.
  int get daysUntilUnlock {
    if (!isLocked) return 0;
    final today = DateTime.now();
    final unlockDay = unlockAt!;
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(unlockDay.year, unlockDay.month, unlockDay.day);
    return b.difference(a).inDays;
  }

  /// 보낸 후 지난 일수 (unlocked 상태에서 "X일 전에 쓴 편지" 표시용)
  int get daysSinceSent {
    if (sentAt == null) return 0;
    final now = DateTime.now();
    final a = DateTime(sentAt!.year, sentAt!.month, sentAt!.day);
    final b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays;
  }

  /// 알림 ID — letter id로부터 결정적 정수 생성.
  /// flutter_local_notifications는 32-bit 정수를 요구.
  int get notificationId {
    // 0x7FFFFFFF = max 32-bit signed int
    return id.hashCode & 0x7FFFFFFF;
  }

  Letter copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
    DateTime? sentAt,
    DateTime? unlockAt,
    bool clearSentAt = false,
    bool clearUnlockAt = false,
  }) {
    return Letter(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      sentAt: clearSentAt ? null : (sentAt ?? this.sentAt),
      unlockAt: clearUnlockAt ? null : (unlockAt ?? this.unlockAt),
    );
  }

  factory Letter.fromJson(Map<String, dynamic> json) {
    return Letter(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'] as String)
          : null,
      unlockAt: json['unlockAt'] != null
          ? DateTime.parse(json['unlockAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        if (sentAt != null) 'sentAt': sentAt!.toIso8601String(),
        if (unlockAt != null) 'unlockAt': unlockAt!.toIso8601String(),
      };
}
