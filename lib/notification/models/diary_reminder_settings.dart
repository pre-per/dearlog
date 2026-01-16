class DiaryReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;
  final bool personalized;

  const DiaryReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.personalized,
  });

  factory DiaryReminderSettings.fromJson(Map<String, dynamic> json) {
    return DiaryReminderSettings(
      enabled: (json['enabled'] ?? false) as bool,
      hour: (json['hour'] ?? 21) as int,
      minute: (json['minute'] ?? 0) as int,
      personalized: (json['personalized'] ?? true) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'personalized': personalized,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  };
}
