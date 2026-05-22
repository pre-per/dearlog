import 'dart:math';

import 'package:dearlog/diary/models/letter.dart';
import 'package:dearlog/notification/service/local_notification_service.dart';
import 'package:dearlog/notification/utils/notification_navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 편지 도착 알림 토글 prefs key. notification_setting_screen 과 동일해야 함.
const _kLetterNotifEnabled = 'letter_notif_enabled';

/// 편지 잠금/알림 스케줄링 헬퍼.
///
/// 정책:
/// - 사용자가 [defaultLockDays] (기본 30일) 또는 직접 선택한 일수만큼 잠금
/// - 잠금 해제 시각은 그날 19:00 (오후 7시)
/// - 1회성 로컬 알림 예약 (편지 채널)
/// - 알림 페이로드는 `letter:{diaryId}` 형식 → 탭 시 해당 일기 detail로 라우팅
class LetterScheduler {
  LetterScheduler({
    LocalNotificationService? notiService,
    Random? random,
  })  : _noti = notiService ?? LocalNotificationService.instance,
        _random = random ?? Random();

  final LocalNotificationService _noti;
  final Random _random;

  /// 기본 잠금 일수. 에디터에서 사용자가 따로 고르지 않으면 이 값으로 봉인됨.
  static const int defaultLockDays = 30;

  /// 잠금 일수 선택 가능 범위 (UI 픽커의 min/max).
  static const int minLockDays = 1;
  static const int maxLockDays = 180;

  /// [디버그 전용] true면 잠금 기간을 0~30초로 단축. false면 정상 lockDays.
  /// 알림 발화 + 도착 메시지까지 E2E 검증할 때 켭니다.
  static bool debugFastMode = false;

  /// 잠금 해제 시각 계산.
  /// 정상: sentAt + lockDays → 그날 오후 7시.
  /// debugFastMode: sentAt + 0~30초.
  ({DateTime sentAt, DateTime unlockAt}) computeLock(
    DateTime now, {
    int lockDays = defaultLockDays,
  }) {
    if (debugFastMode) {
      final seconds = _random.nextInt(31); // 0..30 inclusive
      return (sentAt: now, unlockAt: now.add(Duration(seconds: seconds)));
    }
    final clamped = lockDays.clamp(minLockDays, maxLockDays);
    final base = now.add(Duration(days: clamped));
    final unlockAt = DateTime(base.year, base.month, base.day, 19);
    return (sentAt: now, unlockAt: unlockAt);
  }

  /// 봉인만 — sentAt + unlockAt 부여, 알림 예약 안 함.
  /// 단계별 진행 표시가 필요한 경우 [seal] → 저장 → [schedule] 순으로 호출.
  Letter seal(Letter letter, {DateTime? now, int lockDays = defaultLockDays}) {
    final base = now ?? DateTime.now();
    final lock = computeLock(base, lockDays: lockDays);
    return letter.copyWith(sentAt: lock.sentAt, unlockAt: lock.unlockAt);
  }

  /// 봉인된 편지에 대해 알림 예약만.
  ///
  /// 사용자가 알림 설정에서 "편지 도착 알림"을 꺼 두었으면 schedule 자체를 스킵.
  /// (이미 예약된 옛 편지 알림은 그대로 발사됨 — 토글은 *새* 예약에만 영향)
  Future<void> schedule({
    required Letter sealed,
    required String diaryId,
  }) async {
    if (sealed.sentAt == null || sealed.unlockAt == null) return;

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kLetterNotifEnabled) ?? true;
    if (!enabled) return;

    final daysAgo = sealed.unlockAt!.difference(sealed.sentAt!).inDays;
    await _noti.scheduleOneTimeAt(
      id: sealed.notificationId,
      at: sealed.unlockAt!,
      title: '디어로그',
      body: _bodyForDelivery(daysAgo),
      payload: NotificationPayload.letter(diaryId),
    );
  }

  /// 편의 메서드 — seal + schedule을 한 번에 수행.
  /// 단계별 진행 UI를 보여주려면 위 두 메서드를 직접 사용하세요.
  Future<Letter> send({
    required Letter letter,
    required String diaryId,
    DateTime? now,
    int lockDays = defaultLockDays,
  }) async {
    final sealed = seal(letter, now: now, lockDays: lockDays);
    await schedule(sealed: sealed, diaryId: diaryId);
    return sealed;
  }

  /// 편지 알림을 취소 (편지 삭제/일기 삭제/디버그 즉시 해제 시).
  Future<void> cancel(Letter letter) async {
    await _noti.cancel(letter.notificationId);
  }

  String _bodyForDelivery(int daysAgo) {
    if (daysAgo <= 0) return '내가 나에게 쓴 편지가 도착했어요. 지금 읽어볼까요?';
    return '$daysAgo일 전에 내게 쓴 편지가 도착했어요. 지금 읽어볼까요?';
  }
}
