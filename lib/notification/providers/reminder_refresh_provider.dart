import 'package:dearlog/app.dart';


final reminderSettingsRepoProvider = Provider((ref) {
  return ReminderSettingsRepository(ref.watch(firestoreProvider));
});

final localNotiServiceProvider = Provider((ref) {
  // FlutterLocalNotificationsPlugin 인스턴스는 전역 싱글톤으로 관리 권장
  // (프로젝트에 이미 있으면 그걸 주입)
  throw UnimplementedError("localNoti plugin provider 연결 필요");
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
