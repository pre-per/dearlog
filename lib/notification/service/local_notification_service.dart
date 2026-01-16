import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    if (Platform.isAndroid) {
      // 일반 알림 권한 요청 (Android 13+)
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  /// [Android] 정확한 알람 예약 권한을 확인하고, 없으면 요청 후 함수를 종료하는 헬퍼
  Future<bool> _handleExactAlarmPermission() async {
    if (Platform.isIOS) return true;

    final status = await Permission.scheduleExactAlarm.status;
    if (status.isGranted) {
      return true;
    }

    // 권한이 없다면 요청
    await Permission.scheduleExactAlarm.request();
    debugPrint("정확한 알람 권한이 요청되었습니다. 사용자가 권한을 허용하고 다시 시도해야 합니다.");
    return false; // 권한이 없었으므로 false 반환
  }

  Future<void> scheduleDailyAt({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    // ✅ [최종 수정] permission_handler를 사용한 올바른 권한 처리
    if (!await _handleExactAlarmPermission()) {
      return; // 권한이 없으면 여기서 즉시 중단
    }

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'dearlog_daily',
        'Daily Reminder',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (e) {
      debugPrint("알림 예약 실패(catch): $e");
    }
  }

  Future<void> showTestNow() async {
    debugPrint('showTestNow start');
    // ... (기존 코드와 동일)
  }

  Future<void> scheduleTestIn10Seconds() async {
    // ✅ [최종 수정] permission_handler를 사용한 올바른 권한 처리
    if (!await _handleExactAlarmPermission()) {
      return; // 권한이 없으면 여기서 즉시 중단
    }

    final now = tz.TZDateTime.now(tz.local);
    final next = now.add(const Duration(seconds: 10));

    debugPrint('showTest10 start');

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
      android: AndroidNotificationDetails('dearlog_test', 'Test'),
    );

    try {
      await _plugin.zonedSchedule(
        998,
        '예약 테스트',
        '10초 뒤에 뜨면 성공!',
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_10s',
      );
      debugPrint('showTest10 end');
    } catch (e) {
      debugPrint("10초 알림 예약 실패(catch): $e");
    }
  }
}
