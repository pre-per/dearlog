import 'package:dearlog/app.dart';
import 'package:dearlog/notification/service/local_notification_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kReminderEnabled = 'reminder_enabled';
const _kReminderHour = 'reminder_hour';
const _kReminderMinute = 'reminder_minute';
const _notificationId = 1001;

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({super.key});

  @override
  State<NotificationSettingScreen> createState() => _NotificationSettingScreenState();
}

class _NotificationSettingScreenState extends State<NotificationSettingScreen> {
  bool _enabled = false;
  int _hour = 21;
  int _minute = 0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool(_kReminderEnabled) ?? false;
      _hour = prefs.getInt(_kReminderHour) ?? 21;
      _minute = prefs.getInt(_kReminderMinute) ?? 0;
      _loading = false;
    });
  }

  Future<void> _save({bool? enabled, int? hour, int? minute}) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newEnabled
                ? '매일 ${_formatTime(newHour, newMinute)}에 알림을 드릴게요.'
                : '일일 리마인더가 꺼졌어요.',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _pickTime() {
    int tempHour = _hour;
    int tempMinute = _minute;

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
                      _save(hour: tempHour, minute: tempMinute);
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
                  initialDateTime: DateTime(2024, 1, 1, _hour, _minute),
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
                const SizedBox(height: 8),
                const Text(
                  '일일 리마인더',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '매일 정해진 시간에 오늘 하루를 기록하도록 알려드려요.',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                _SettingCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('리마인더 켜기', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      _saving
                          ? const SizedBox(width: 40, height: 24, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                          : CupertinoSwitch(
                              value: _enabled,
                              activeColor: const Color(0xFFFFD700),
                              onChanged: (v) => _save(enabled: v),
                            ),
                    ],
                  ),
                ),
                if (_enabled) ...[
                  const SizedBox(height: 12),
                  _SettingCard(
                    onTap: _pickTime,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('알림 시간', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
