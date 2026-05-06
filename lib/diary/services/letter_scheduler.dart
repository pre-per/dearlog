import 'dart:math';

import 'package:dearlog/diary/models/letter.dart';
import 'package:dearlog/notification/service/local_notification_service.dart';
import 'package:dearlog/notification/utils/notification_navigator.dart';

/// 편지 잠금/알림 스케줄링 헬퍼.
///
/// 정책:
/// - 보내기를 누르면 30~40일 사이 랜덤 일수가 잠금 기간이 됨
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

  /// [디버그 전용] true면 잠금 기간을 0~30초로 단축. false면 정상 30~40일.
  /// 알림 발화 + 도착 메시지까지 E2E 검증할 때 켭니다.
  static bool debugFastMode = false;

  /// 잠금 해제 시각 계산.
  /// 정상: sentAt + (30~40일 사이 랜덤) → 그날 오후 7시.
  /// debugFastMode: sentAt + 0~30초.
  ({DateTime sentAt, DateTime unlockAt}) computeLock(DateTime now) {
    if (debugFastMode) {
      final seconds = _random.nextInt(31); // 0..30 inclusive
      return (sentAt: now, unlockAt: now.add(Duration(seconds: seconds)));
    }
    final lockDays = 30 + _random.nextInt(11); // 30..40 inclusive
    final base = now.add(Duration(days: lockDays));
    final unlockAt = DateTime(base.year, base.month, base.day, 19);
    return (sentAt: now, unlockAt: unlockAt);
  }

  /// 봉인만 — sentAt + unlockAt 부여, 알림 예약 안 함.
  /// 단계별 진행 표시가 필요한 경우 [seal] → 저장 → [schedule] 순으로 호출.
  Letter seal(Letter letter, {DateTime? now}) {
    final base = now ?? DateTime.now();
    final lock = computeLock(base);
    return letter.copyWith(sentAt: lock.sentAt, unlockAt: lock.unlockAt);
  }

  /// 봉인된 편지에 대해 알림 예약만.
  Future<void> schedule({
    required Letter sealed,
    required String diaryId,
  }) async {
    if (sealed.sentAt == null || sealed.unlockAt == null) return;
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
  }) async {
    final sealed = seal(letter, now: now);
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
