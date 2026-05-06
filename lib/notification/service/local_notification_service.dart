import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../utils/notification_navigator.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── 채널 정의 ──
  static const String dailyChannelId = 'dearlog_daily';
  static const String dailyChannelName = '일일 리마인더';
  static const String dailyChannelDesc = '매일 정해진 시간에 일기 작성을 알려드려요';

  static const String letterChannelId = 'dearlog_letter';
  static const String letterChannelName = '편지 도착 알림';
  static const String letterChannelDesc = '내가 보낸 편지가 도착하면 알려드려요';

  static const String testChannelId = 'dearlog_test';
  static const String testChannelName = '테스트 알림';
  static const String testChannelDesc = '동작 확인용';

  Future<void> init() async {
    // ✅ 모든 알림 진단 로그는 [NOTI] 일관된 prefix 로 통일.
    //    release 빌드에서도 logcat 'flutter' 태그로 확인 가능하도록
    //    중요한 분기/결과는 print() 사용 (debugPrint 는 throttling 으로
    //    드물게 누락되는 경우가 있음).
    print('[NOTI] init: 시작');

    // 1) 타임존
    tz.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
      print('[NOTI] timezone identifier=${localTimezone.identifier}');
    } catch (e) {
      print('[NOTI] ❌ flutter_timezone 실패, 시스템 기본값 사용: $e');
    }

    // 2) Android POST_NOTIFICATIONS (13+) 권한 요청 + 결과 로그
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      print('[NOTI] Android POST_NOTIFICATIONS 허용: $granted');
      if (granted != true) {
        // false 또는 null 이면 사용자에게 알림이 절대 안 옴 — 가장 흔한 함정.
        print('[NOTI] ⚠️ POST_NOTIFICATIONS 미허용 — 알림이 표시되지 않습니다.');
      }
    }

    // 3) 플러그인 초기화 + 탭 핸들러
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    final initialized = await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        print('[NOTI] 탭 수신: payload=${response.payload}');
        NotificationCenter.post(response.payload);
      },
    );
    print('[NOTI] plugin.initialize 결과: $initialized');

    // 4) Android 채널 명시 생성 (Android 8+)
    //    plugin이 자동 생성하긴 하지만, importance/desc/sound 보장 위해 직접 생성.
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          dailyChannelId,
          dailyChannelName,
          description: dailyChannelDesc,
          importance: Importance.max,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          letterChannelId,
          letterChannelName,
          description: letterChannelDesc,
          importance: Importance.max,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          testChannelId,
          testChannelName,
          description: testChannelDesc,
          importance: Importance.high,
        ),
      );
      print('[NOTI] Android 채널 3개 생성 완료 '
          '($dailyChannelId, $letterChannelId, $testChannelId)');
    }

    // 5) 콜드 스타트 — 알림 탭으로 앱이 켜졌는지 확인 후 페이로드 큐잉
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      print('[NOTI] 콜드 스타트 진입 payload=$payload');
      NotificationCenter.post(payload);
    }
    print('[NOTI] init: 완료');
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<List<PendingNotificationRequest>> getPending() {
    return _plugin.pendingNotificationRequests();
  }

  /// [Android] 정확한 알람 예약 권한 확인 및 요청
  Future<bool> _handleExactAlarmPermission() async {
    if (Platform.isIOS) return true;

    final status = await Permission.scheduleExactAlarm.status;
    if (status.isGranted) return true;

    await Permission.scheduleExactAlarm.request();
    return (await Permission.scheduleExactAlarm.status).isGranted;
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
        dailyChannelId,
        dailyChannelName,
        channelDescription: dailyChannelDesc,
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
      print(
        '[NOTI] 일일 예약 OK: $hour:$minute id=$id '
        '(${hasExactAlarm ? "exact" : "inexact"}, next=$next)',
      );
    } catch (e, st) {
      print('[NOTI] ❌ 일일 예약 실패: $e');
      print('[NOTI] stack: $st');
    }
  }

  /// 1회성 예약 — 편지 잠금 해제 같은 시간 고정 알림에 사용.
  /// [at]는 로컬 타임존 기준 DateTime.
  Future<void> scheduleOneTimeAt({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    String channelId = letterChannelId,
    String channelName = letterChannelName,
    String channelDesc = letterChannelDesc,
  }) async {
    final hasExactAlarm = await _handleExactAlarmPermission();

    final scheduled = tz.TZDateTime.from(at, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (scheduled.isBefore(now)) {
      print('[NOTI] ⚠️ 1회성 예약 취소: 과거 시간 $at');
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
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
        scheduled,
        details,
        androidScheduleMode: hasExactAlarm
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // matchDateTimeComponents 미지정 = 1회성
        payload: payload,
      );
      print(
        '[NOTI] 1회성 예약 OK: $scheduled id=$id '
        '(${hasExactAlarm ? "exact" : "inexact"})',
      );
    } catch (e, st) {
      print('[NOTI] ❌ 1회성 예약 실패: $e');
      print('[NOTI] stack: $st');
    }
  }

  /// 채널/권한 즉시 동작 확인용
  Future<void> showTestNow() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        testChannelId,
        testChannelName,
        channelDescription: testChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
    try {
      await _plugin.show(
        999,
        '디어로그',
        '알림이 정상적으로 도착했어요 🌙',
        details,
        payload: 'test_now',
      );
      print('[NOTI] 즉시 표시 OK (id=999, channel=$testChannelId)');
    } catch (e, st) {
      print('[NOTI] ❌ 즉시 표시 실패: $e');
      print('[NOTI] stack: $st');
    }
  }

  Future<void> scheduleTestIn10Seconds() async {
    final hasExactAlarm = await _handleExactAlarmPermission();
    final now = tz.TZDateTime.now(tz.local);
    final next = now.add(const Duration(seconds: 10));

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
      android: AndroidNotificationDetails(
        testChannelId,
        testChannelName,
        channelDescription: testChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
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
      print('[NOTI] 10초 예약 OK '
          '(${hasExactAlarm ? "exact" : "inexact"}, fire=$next)');
    } catch (e, st) {
      print('[NOTI] ❌ 10초 예약 실패: $e');
      print('[NOTI] stack: $st');
    }
  }
}
