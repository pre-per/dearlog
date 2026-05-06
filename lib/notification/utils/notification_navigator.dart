import 'package:flutter/material.dart';

/// 알림 탭으로부터의 네비게이션을 위한 글로벌 키.
/// MaterialApp의 navigatorKey에 연결되어 위젯 컨텍스트 없이도 push 가능.
final GlobalKey<NavigatorState> notificationNavigatorKey =
    GlobalKey<NavigatorState>();

/// 알림 탭 페이로드 브로커.
/// - 콜드 스타트 시 init()에서 launchDetails 페이로드를 post.
/// - 백그라운드/포그라운드 탭은 onDidReceiveNotificationResponse에서 post.
/// - MainScreen 등이 ValueListenableBuilder로 구독하여 처리 후 [consume].
class NotificationCenter {
  NotificationCenter._();

  static final ValueNotifier<String?> pendingPayload = ValueNotifier(null);

  static void post(String? payload) {
    if (payload == null || payload.isEmpty) return;
    pendingPayload.value = payload;
  }

  /// 처리 후 호출하여 같은 페이로드가 중복 dispatch되지 않게 비움.
  static String? consume() {
    final v = pendingPayload.value;
    pendingPayload.value = null;
    return v;
  }
}

/// 페이로드 포맷 약속:
/// - "daily_reminder"          : 일일 리마인더 → 일기 작성 유도
/// - "letter:{diaryId}"        : 편지 잠금 해제 → 해당 일기 detail
/// - "test_*"                  : 테스트
class NotificationPayload {
  static const String dailyReminder = 'daily_reminder';
  static const String letterPrefix = 'letter:';

  static String letter(String diaryId) => '$letterPrefix$diaryId';

  static String? extractDiaryId(String payload) {
    if (!payload.startsWith(letterPrefix)) return null;
    final id = payload.substring(letterPrefix.length).trim();
    return id.isEmpty ? null : id;
  }
}
