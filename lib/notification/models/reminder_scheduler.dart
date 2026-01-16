import 'package:dearlog/app.dart';

class ReminderScheduler {
  static const int reminderId = 100;

  final ReminderSettingsRepository settingsRepo;
  final DiaryRepository diaryRepo;
  final LocalNotificationService localNoti;

  ReminderScheduler({
    required this.settingsRepo,
    required this.diaryRepo,
    required this.localNoti,
  });

  Future<void> refresh(String uid) async {
    final DiaryReminderSettings? settings = await settingsRepo.getSettings(uid);

    // 설정이 없으면 아무것도 안 함(또는 기본값으로 생성해도 됨)
    if (settings == null) return;

    if (!settings.enabled) {
      await localNoti.cancel(reminderId);
      return;
    }

    final last = await diaryRepo.fetchLatestDiary(uid);
    final daysSince = last == null ? 999 : DateTime.now().difference(last.date).inDays;

    final body = settings.personalized
        ? buildReminderBody(last, daysSince)
        : "오늘 하루는 어땠나요? 디어로그에 기록해볼까요?";

    await localNoti.cancel(reminderId);
    await localNoti.scheduleDailyAt(
      id: reminderId,
      hour: settings.hour,
      minute: settings.minute,
      title: "디어로그",
      body: body,
      payload: "route=write_diary",
    );
  }
}
