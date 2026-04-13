import 'package:dearlog/app.dart';
import 'package:dearlog/notification/service/local_notification_service.dart';


final reminderSettingsRepoProvider = Provider((ref) {
  return ReminderSettingsRepository(ref.watch(firestoreProvider));
});

final localNotiServiceProvider = Provider((ref) {
  return LocalNotificationService.instance;
});

final reminderSchedulerProvider = Provider((ref) {
  return ReminderScheduler(
    settingsRepo: ref.watch(reminderSettingsRepoProvider),
    diaryRepo: ref.watch(diaryRepositoryProvider),
    localNoti: ref.watch(localNotiServiceProvider),
  );
});

final reminderRefreshProvider = Provider((ref) {
  return (String uid) => ref.read(reminderSchedulerProvider).refresh(uid);
});
