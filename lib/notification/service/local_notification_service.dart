import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 기기의 로컬 timezone을 정확히 설정
    tz.initializeTimeZones();

    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

      debugPrint(
        '[Timezone] identifier: ${localTimezone.identifier}, '
            'localizedName: ${localTimezone.localizedName}',
      );
    } catch (e) {
      debugPrint('[Timezone] flutter_timezone 미적용, 시스템 기본값 사용: $e');
    }

    if (Platform.isAndroid) {
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

    const settings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _plugin.initialize(settings);
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  /// [Android] 정확한 알람 예약 권한 확인 및 요청
  /// 반환값: 권한 허용 여부
  Future<bool> _handleExactAlarmPermission() async {
    if (Platform.isIOS) return true;

    final status = await Permission.scheduleExactAlarm.status;
    if (status.isGranted) return true;

    await Permission.scheduleExactAlarm.request();
    final afterRequest = await Permission.scheduleExactAlarm.status;
    return afterRequest.isGranted;
  }

  Future<void> scheduleDailyAt({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    final hasExactAlarm = await _handleExactAlarmPermission();

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }

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
        androidScheduleMode: hasExactAlarm
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );

      debugPrint(
        '[알림] 예약 완료: $hour:$minute (${hasExactAlarm ? 'exact' : 'inexact'})',
      );
    } catch (e) {
      debugPrint('[알림] 예약 실패: $e');
    }
  }

  Future<void> showTestNow() async {
    debugPrint('showTestNow start');
    // 기존 코드
  }

  Future<void> scheduleTestIn10Seconds() async {
    final hasExactAlarm = await _handleExactAlarmPermission();

    final now = tz.TZDateTime.now(tz.local);
    final next = now.add(const Duration(seconds: 10));

    debugPrint('showTest10 start');

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
      android: AndroidNotificationDetails(
        'dearlog_test',
        'Test',
      ),
    );

    try {
      await _plugin.zonedSchedule(
        998,
        '예약 테스트',
        '10초 뒤에 뜨면 성공!',
        next,
        details,
        androidScheduleMode: hasExactAlarm
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_10s',
      );

      debugPrint('showTest10 end');
    } catch (e) {
      debugPrint('[알림] 10초 예약 실패: $e');
    }
  }
}