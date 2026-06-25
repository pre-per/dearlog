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

  // 커뮤니티 댓글 등 원격 푸시(FCM) 알림용 채널.
  // Cloud Functions(`functions/index.js`) 의 `notification.android.channelId` 와 동일해야 함.
  static const String communityChannelId = 'dearlog_community';
  static const String communityChannelName = '커뮤니티 활동';
  static const String communityChannelDesc = '내 공개 게시물에 댓글이 달리면 알려드려요';

  // 오늘의 운세 일일 알림용 채널.
  // (구버전 채널 ID 'dearlog_zodiac' 은 별자리 운세 시절 사용. Android 가
  //  채널 ID 변경 시 새 채널을 인식하지 못해 알림이 잠시 사라지지 않도록
  //  여기서는 신규 ID 'dearlog_daily_fortune' 로 분리.)
  static const String dailyFortuneChannelId = 'dearlog_daily_fortune';
  static const String dailyFortuneChannelName = '오늘의 운세';
  static const String dailyFortuneChannelDesc = '매일 아침 오늘의 운세가 담긴 유리병이 도착해요';

  Future<void> init() async {
    // ✅ 모든 알림 진단 로그는 [NOTI] 일관된 prefix 로 통일.
    //    release 빌드에서도 logcat 'flutter' 태그로 확인 가능하도록
    //    중요한 분기/결과는 debugPrint() 사용 (debugPrint 는 throttling 으로
    //    드물게 누락되는 경우가 있음).
    debugPrint('[NOTI] init: 시작');

    // 1) 타임존
    tz.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
      debugPrint('[NOTI] timezone identifier=${localTimezone.identifier}');
    } catch (e) {
      debugPrint('[NOTI] ❌ flutter_timezone 실패, 시스템 기본값 사용: $e');
    }

    // 2) Android POST_NOTIFICATIONS (13+) 권한 요청 + 결과 로그
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      debugPrint('[NOTI] Android POST_NOTIFICATIONS 허용: $granted');
      if (granted != true) {
        // false 또는 null 이면 사용자에게 알림이 절대 안 옴 — 가장 흔한 함정.
        debugPrint('[NOTI] ⚠️ POST_NOTIFICATIONS 미허용 — 알림이 표시되지 않습니다.');
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
        debugPrint('[NOTI] 탭 수신: payload=${response.payload}');
        NotificationCenter.post(response.payload);
      },
    );
    debugPrint('[NOTI] plugin.initialize 결과: $initialized');

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
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          communityChannelId,
          communityChannelName,
          description: communityChannelDesc,
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          dailyFortuneChannelId,
          dailyFortuneChannelName,
          description: dailyFortuneChannelDesc,
          importance: Importance.high,
        ),
      );
      debugPrint('[NOTI] Android 채널 5개 생성 완료 '
          '($dailyChannelId, $letterChannelId, $testChannelId, $communityChannelId, $dailyFortuneChannelId)');
    }

    // 5) 콜드 스타트 — 알림 탭으로 앱이 켜졌는지 확인 후 페이로드 큐잉
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      debugPrint('[NOTI] 콜드 스타트 진입 payload=$payload');
      NotificationCenter.post(payload);
    }
    debugPrint('[NOTI] init: 완료');
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
    String channelId = dailyChannelId,
    String channelName = dailyChannelName,
    String channelDesc = dailyChannelDesc,
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
        '[NOTI] 일일 예약 OK: $hour:$minute id=$id '
        '(${hasExactAlarm ? "exact" : "inexact"}, next=$next)',
      );
    } catch (e, st) {
      debugPrint('[NOTI] ❌ 일일 예약 실패: $e');
      debugPrint('[NOTI] stack: $st');
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
      debugPrint('[NOTI] ⚠️ 1회성 예약 취소: 과거 시간 $at');
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
      debugPrint(
        '[NOTI] 1회성 예약 OK: $scheduled id=$id '
        '(${hasExactAlarm ? "exact" : "inexact"})',
      );
    } catch (e, st) {
      debugPrint('[NOTI] ❌ 1회성 예약 실패: $e');
      debugPrint('[NOTI] stack: $st');
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
      debugPrint('[NOTI] 즉시 표시 OK (id=999, channel=$testChannelId)');
    } catch (e, st) {
      debugPrint('[NOTI] ❌ 즉시 표시 실패: $e');
      debugPrint('[NOTI] stack: $st');
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
      debugPrint('[NOTI] 10초 예약 OK '
          '(${hasExactAlarm ? "exact" : "inexact"}, fire=$next)');
    } catch (e, st) {
      debugPrint('[NOTI] ❌ 10초 예약 실패: $e');
      debugPrint('[NOTI] stack: $st');
    }
  }
}
