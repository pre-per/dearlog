import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dearlog/app.dart';
import 'package:dearlog/fortune/services/daily_fortune_notification.dart';
import 'package:dearlog/notification/service/local_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kReminderEnabled = 'reminder_enabled';
const _kReminderHour = 'reminder_hour';
const _kReminderMinute = 'reminder_minute';
const _kLetterNotifEnabled = 'letter_notif_enabled';
const _kCommentNotifEnabled = 'comment_notif_enabled';
const _kCommunityRecapEnabled = 'community_recap_enabled';
const _kCommunityRecapHour = 'community_recap_hour';
const _kCommunityRecapMinute = 'community_recap_minute';
const _notificationId = 1001;

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({super.key});

  @override
  State<NotificationSettingScreen> createState() => _NotificationSettingScreenState();
}

class _NotificationSettingScreenState extends State<NotificationSettingScreen>
    with WidgetsBindingObserver {
  bool _enabled = false;
  int _hour = 21;
  int _minute = 0;
  bool _letterEnabled = true;
  bool _commentEnabled = true;
  bool _fortuneEnabled = DailyFortuneNotificationScheduler.defaultEnabled;
  int _fortuneHour = DailyFortuneNotificationScheduler.defaultHour;
  int _fortuneMinute = DailyFortuneNotificationScheduler.defaultMinute;
  bool _fortuneSaving = false;
  // 커뮤니티 일일 알림 — Cloud Functions 가 서버에서 발송 (commentNotifEnabled 와 동일 패턴).
  bool _recapEnabled = false;
  int _recapHour = 19;
  int _recapMinute = 0;
  bool _recapSaving = false;
  bool _loading = true;
  bool _saving = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 설정 앱에서 돌아왔을 때 권한 상태 재확인
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission();
    }
  }

  Future<void> _checkNotificationPermission() async {
    final denied = await _isNotificationPermissionDenied();
    if (mounted) setState(() => _permissionDenied = denied);
  }

  /// iOS는 permission_handler가 notDetermined를 denied로 잘못 반환하는 문제가 있어
  /// FirebaseMessaging.getNotificationSettings()로 정확한 상태를 확인
  Future<bool> _isNotificationPermissionDenied() async {
    if (Platform.isIOS) {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.denied;
    }
    final status = await Permission.notification.status;
    return status.isDenied || status.isPermanentlyDenied;
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final denied = await _isNotificationPermissionDenied();
    setState(() {
      _enabled = prefs.getBool(_kReminderEnabled) ?? false;
      _hour = prefs.getInt(_kReminderHour) ?? 21;
      _minute = prefs.getInt(_kReminderMinute) ?? 0;
      // 편지/커뮤니티 알림 기본값은 ON. (기존 사용자가 새 prefs key 를 만나면 켠 상태로 간주)
      _letterEnabled = prefs.getBool(_kLetterNotifEnabled) ?? true;
      _commentEnabled = prefs.getBool(_kCommentNotifEnabled) ?? true;
      _fortuneEnabled =
          prefs.getBool(DailyFortuneNotificationScheduler.prefsEnabled) ??
              DailyFortuneNotificationScheduler.defaultEnabled;
      _fortuneHour = prefs.getInt(DailyFortuneNotificationScheduler.prefsHour) ??
          DailyFortuneNotificationScheduler.defaultHour;
      _fortuneMinute =
          prefs.getInt(DailyFortuneNotificationScheduler.prefsMinute) ??
              DailyFortuneNotificationScheduler.defaultMinute;
      // 커뮤니티 일일 알림 기본값은 OFF — 새 사용자에게 사전 동의 없이 push 를 보내지 않는다.
      _recapEnabled = prefs.getBool(_kCommunityRecapEnabled) ?? false;
      _recapHour = prefs.getInt(_kCommunityRecapHour) ?? 19;
      _recapMinute = prefs.getInt(_kCommunityRecapMinute) ?? 0;
      _permissionDenied = denied;
      _loading = false;
    });
  }

  // ───── 일일 리마인더 ─────

  Future<void> _saveReminder({bool? enabled, int? hour, int? minute}) async {
    setState(() => _saving = true);

    final newEnabled = enabled ?? _enabled;
    final newHour = hour ?? _hour;
    final newMinute = minute ?? _minute;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReminderEnabled, newEnabled);
    await prefs.setInt(_kReminderHour, newHour);
    await prefs.setInt(_kReminderMinute, newMinute);

    if (newEnabled) {
      await LocalNotificationService.instance.scheduleDailyAt(
        id: _notificationId,
        hour: newHour,
        minute: newMinute,
        title: '오늘 하루는 어땠나요?',
        body: '잠깐 대화하며 오늘을 기록해보세요 🌙',
        payload: 'daily_reminder',
      );
    } else {
      await LocalNotificationService.instance.cancel(_notificationId);
    }

    setState(() {
      _enabled = newEnabled;
      _hour = newHour;
      _minute = newMinute;
      _saving = false;
    });

    if (mounted) {
      _toast(
        newEnabled
            ? '매일 ${_formatTime(newHour, newMinute)}에 알림을 드릴게요.'
            : '일일 리마인더가 꺼졌어요.',
      );
    }
  }

  // ───── 편지 도착 알림 ─────

  Future<void> _saveLetter(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLetterNotifEnabled, v);
    setState(() => _letterEnabled = v);
    if (mounted) {
      _toast(v
          ? '편지 도착 알림을 켰어요.'
          : '편지 도착 알림을 껐어요. 새로 보내는 편지부터 알림이 가지 않아요.');
    }
  }

  // ───── 커뮤니티 댓글 알림 ─────
  //
  // 클라이언트 prefs 외에 서버측에서도 즉시 차단되도록 Firestore user doc 의
  // `commentNotifEnabled` 필드를 미러링한다. Cloud Functions 의
  // notifyOnNewComment 가 이 필드를 읽어 false 면 푸시를 보내지 않는다.
  Future<void> _saveCommunity(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCommentNotifEnabled, v);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .doc('users/$uid')
            .set({'commentNotifEnabled': v}, SetOptions(merge: true));
      } catch (e) {
        // 네트워크 실패 등은 prefs 만 저장하고 다음 기회에 재시도 — 하지만
        // 사용자에게는 실패한 사실을 알려준다.
        if (mounted) _toast('서버 동기화에 실패했어요: $e');
        return;
      }
    }

    setState(() => _commentEnabled = v);
    if (mounted) {
      _toast(v ? '커뮤니티 댓글 알림을 켰어요.' : '커뮤니티 댓글 알림을 껐어요.');
    }
  }

  // ───── 커뮤니티 일일 알림 ─────
  //
  // Cloud Functions 가 매 N 분 cron 으로 돌면서 user doc 의
  // dailyCommunityNotifSlot/Enabled 를 보고 발송하므로, 클라이언트는 prefs +
  // Firestore 미러만 한다. (LocalNotificationService 와 무관)
  Future<void> _saveCommunityRecap({
    bool? enabled,
    int? hour,
    int? minute,
  }) async {
    setState(() => _recapSaving = true);

    final newEnabled = enabled ?? _recapEnabled;
    final newHour = hour ?? _recapHour;
    final newMinute = minute ?? _recapMinute;
    final newSlot = newHour * 60 + newMinute;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCommunityRecapEnabled, newEnabled);
    await prefs.setInt(_kCommunityRecapHour, newHour);
    await prefs.setInt(_kCommunityRecapMinute, newMinute);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.doc('users/$uid').set({
          'dailyCommunityNotifEnabled': newEnabled,
          'dailyCommunityNotifHour': newHour,
          'dailyCommunityNotifMinute': newMinute,
          'dailyCommunityNotifSlot': newSlot,
        }, SetOptions(merge: true));
      } catch (e) {
        if (mounted) _toast('서버 동기화에 실패했어요: $e');
        setState(() => _recapSaving = false);
        return;
      }
    }

    setState(() {
      _recapEnabled = newEnabled;
      _recapHour = newHour;
      _recapMinute = newMinute;
      _recapSaving = false;
    });

    if (mounted) {
      _toast(
        newEnabled
            ? '매일 ${_formatTime(newHour, newMinute)}쯤 새 게시글 알림을 드릴게요.'
            : '커뮤니티 일일 알림이 꺼졌어요.',
      );
    }
  }

  // ───── 오늘의 운세 알림 ─────

  Future<void> _saveFortune({bool? enabled, int? hour, int? minute}) async {
    setState(() => _fortuneSaving = true);

    final newEnabled = enabled ?? _fortuneEnabled;
    final newHour = hour ?? _fortuneHour;
    final newMinute = minute ?? _fortuneMinute;

    await DailyFortuneNotificationScheduler.save(
      enabled: newEnabled,
      hour: newHour,
      minute: newMinute,
    );

    setState(() {
      _fortuneEnabled = newEnabled;
      _fortuneHour = newHour;
      _fortuneMinute = newMinute;
      _fortuneSaving = false;
    });

    if (mounted) {
      _toast(
        newEnabled
            ? '매일 ${_formatTime(newHour, newMinute)}에 오늘의 운세를 알려드릴게요.'
            : '오늘의 운세 알림이 꺼졌어요.',
      );
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _pickTime() {
    _showTimePicker(
      initialHour: _hour,
      initialMinute: _minute,
      onPicked: (h, m) => _saveReminder(hour: h, minute: m),
    );
  }

  void _pickFortuneTime() {
    _showTimePicker(
      initialHour: _fortuneHour,
      initialMinute: _fortuneMinute,
      onPicked: (h, m) => _saveFortune(hour: h, minute: m),
    );
  }

  void _pickRecapTime() {
    _showTimePicker(
      initialHour: _recapHour,
      initialMinute: _recapMinute,
      onPicked: (h, m) => _saveCommunityRecap(hour: h, minute: m),
    );
  }

  void _showTimePicker({
    required int initialHour,
    required int initialMinute,
    required void Function(int hour, int minute) onPicked,
  }) {
    int tempHour = initialHour;
    int tempMinute = initialMinute;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 280,
        color: const Color(0xFF1C1C2E),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소', style: TextStyle(color: Colors.white70)),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onPicked(tempHour, tempMinute);
                    },
                    child: const Text('완료', style: TextStyle(color: Color(0xFFFFD700))),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Localizations.override(
                context: context,
                locale: const Locale('ko', 'KR'),
                delegates: [
                  GlobalCupertinoLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false,
                  initialDateTime:
                      DateTime(2024, 1, 1, initialHour, initialMinute),
                  onDateTimeChanged: (dt) {
                    tempHour = dt.hour;
                    tempMinute = dt.minute;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int h, int m) {
    final period = h < 12 ? '오전' : '오후';
    final displayHour = h % 12 == 0 ? 12 : h % 12;
    final displayMinute = m.toString().padLeft(2, '0');
    return '$period $displayHour:$displayMinute';
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      appBar: AppBar(
        title: const Text('알림 설정'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                if (_permissionDenied) ...[
                  const SizedBox(height: 8),
                  _PermissionBanner(
                    onTap: () async {
                      await openAppSettings();
                    },
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 8),

                // ── 일일 리마인더 ──
                _ToggleCard(
                  title: '일일 리마인더',
                  subtitle: '매일 정해진 시간에 일기 작성을 알려드려요',
                  value: _enabled,
                  saving: _saving,
                  onChanged: (v) => _saveReminder(enabled: v),
                ),
                if (_enabled) ...[
                  const SizedBox(height: 12),
                  _SettingCard(
                    onTap: _pickTime,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '알림 시간',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatTime(_hour, _minute),
                              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ── 편지 도착 알림 ──
                _ToggleCard(
                  title: '편지 도착 알림',
                  subtitle: '내가 보낸 편지가 도착하면 알려드려요',
                  value: _letterEnabled,
                  onChanged: _saveLetter,
                ),

                const SizedBox(height: 12),

                // ── 커뮤니티 댓글 알림 ──
                _ToggleCard(
                  title: '커뮤니티 댓글 알림',
                  subtitle: '내 공개 게시물에 댓글이 달리면 알려드려요',
                  value: _commentEnabled,
                  onChanged: _saveCommunity,
                ),

                const SizedBox(height: 12),

                // ── 오늘의 운세 알림 ──
                _ToggleCard(
                  title: '오늘의 운세 알림',
                  subtitle: '매일 아침 오늘의 운세가 담긴 유리병이 도착해요',
                  value: _fortuneEnabled,
                  saving: _fortuneSaving,
                  onChanged: (v) => _saveFortune(enabled: v),
                ),
                if (_fortuneEnabled) ...[
                  const SizedBox(height: 12),
                  _SettingCard(
                    onTap: _pickFortuneTime,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '알림 시간',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatTime(_fortuneHour, _fortuneMinute),
                              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ── 커뮤니티 일일 알림 ──
                _ToggleCard(
                  title: '커뮤니티 일일 알림',
                  subtitle: '하루 한 번 새 게시글을 알려드려요',
                  value: _recapEnabled,
                  saving: _recapSaving,
                  onChanged: (v) => _saveCommunityRecap(enabled: v),
                ),
                if (_recapEnabled) ...[
                  const SizedBox(height: 12),
                  _SettingCard(
                    onTap: _pickRecapTime,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '알림 시간',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatTime(_recapHour, _recapMinute),
                              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// 좌측 제목+부제목 / 우측 CupertinoSwitch 한 줄 토글 카드.
class _ToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool saving;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          saving
              ? const SizedBox(
                  width: 40,
                  height: 24,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : CupertinoSwitch(
                  value: value,
                  activeColor: const Color(0xFFFFD700),
                  onChanged: onChanged,
                ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PermissionBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined, color: Color(0xFFFFD700), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '알림 권한이 꺼져 있어요.\n알림을 받으려면 권한을 허용해 주세요.',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '설정 열기',
                style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _SettingCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: child,
      ),
    );
  }
}
