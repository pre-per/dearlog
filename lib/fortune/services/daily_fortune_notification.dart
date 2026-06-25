import 'package:shared_preferences/shared_preferences.dart';

import '../../notification/service/local_notification_service.dart';
import '../../notification/utils/notification_navigator.dart';

/// 오늘의 운세 일일 알림 (로컬) 스케줄러.
///
/// - SharedPreferences 키 3종에 사용자 설정을 보관.
/// - [refresh] 는 설정 변경 시 또는 앱 시작 시 호출 — 현재 설정에 맞춰
///   기존 예약을 cancel 하고 새로 등록한다.
class DailyFortuneNotificationScheduler {
  DailyFortuneNotificationScheduler._();

  /// flutter_local_notifications 의 id. 다른 알림과 충돌하지 않게 고유값.
  static const int notificationId = 2001;

  static const String prefsEnabled = 'daily_fortune_notif_enabled';
  static const String prefsHour = 'daily_fortune_notif_hour';
  static const String prefsMinute = 'daily_fortune_notif_minute';

  /// 기본값 — 사용자가 한 번도 설정하지 않은 상태에서 운세 알림은 OFF.
  /// 켤 때 기본 시간은 아침 7시.
  static const bool defaultEnabled = false;
  static const int defaultHour = 7;
  static const int defaultMinute = 0;

  /// 현재 prefs 의 설정을 읽어 알림을 (재)예약. 비활성화면 cancel.
  static Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(prefsEnabled) ?? defaultEnabled;
    final hour = prefs.getInt(prefsHour) ?? defaultHour;
    final minute = prefs.getInt(prefsMinute) ?? defaultMinute;

    await LocalNotificationService.instance.cancel(notificationId);
    if (!enabled) return;

    await LocalNotificationService.instance.scheduleDailyAt(
      id: notificationId,
      hour: hour,
      minute: minute,
      title: '오늘의 운세가 도착했어요',
      body: '홈에 떠 있는 유리병을 열어보세요 ✨',
      payload: NotificationPayload.dailyFortune,
      channelId: LocalNotificationService.dailyFortuneChannelId,
      channelName: LocalNotificationService.dailyFortuneChannelName,
      channelDesc: LocalNotificationService.dailyFortuneChannelDesc,
    );
  }

  /// 설정 화면에서 ON/OFF 또는 시간 변경 시 호출.
  static Future<void> save({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsEnabled, enabled);
    await prefs.setInt(prefsHour, hour);
    await prefs.setInt(prefsMinute, minute);
    await refresh();
  }
}
