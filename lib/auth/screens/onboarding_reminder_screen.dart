import 'package:dearlog/app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 회원가입 5단계(마지막) — 매일 일기 알림 설정.
///
/// 회원가입 직후 자연스럽게 한 번만 권하는 화면. 사용자가 켜면 prefs 저장 +
/// 즉시 일일 알림 예약, 끄면 prefs 만 false 로 두고 통과.
/// 이후 변경은 [NotificationSettingScreen] 에서 가능.
class OnboardingReminderScreen extends ConsumerStatefulWidget {
  const OnboardingReminderScreen({super.key});

  @override
  ConsumerState<OnboardingReminderScreen> createState() =>
      _OnboardingReminderScreenState();
}

class _OnboardingReminderScreenState
    extends ConsumerState<OnboardingReminderScreen> {
  // 알림 설정 화면과 동일한 prefs key. 한 곳에서 바꾸면 다른 화면도 그 값을 읽어감.
  static const _kReminderEnabled = 'reminder_enabled';
  static const _kReminderHour = 'reminder_hour';
  static const _kReminderMinute = 'reminder_minute';
  static const _notificationId = 1001;

  int _hour = 21;
  int _minute = 0;
  bool _saving = false;

  Future<void> _enableAndContinue() async {
    if (_saving) return;
    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReminderEnabled, true);
    await prefs.setInt(_kReminderHour, _hour);
    await prefs.setInt(_kReminderMinute, _minute);

    try {
      await LocalNotificationService.instance.scheduleDailyAt(
        id: _notificationId,
        hour: _hour,
        minute: _minute,
        title: '오늘 하루는 어땠나요?',
        body: '잠깐 대화하며 오늘을 기록해보세요 🌙',
        payload: 'daily_reminder',
      );
    } catch (e) {
      debugPrint('[onboarding-reminder] schedule failed: $e');
    }

    if (!mounted) return;
    _goToMain();
  }

  Future<void> _skipAndContinue() async {
    if (_saving) return;
    final prefs = await SharedPreferences.getInstance();
    // 명시적으로 false 저장 — 이후 NotificationSettingScreen 에서도 OFF 로 보이게.
    await prefs.setBool(_kReminderEnabled, false);
    if (!mounted) return;
    _goToMain();
  }

  void _goToMain() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (_) => false,
    );
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
                    child: const Text('취소',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      setState(() {
                        _hour = tempHour;
                        _minute = tempMinute;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('완료',
                        style: TextStyle(color: Color(0xFFFFD700))),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Localizations.override(
                context: context,
                locale: const Locale('ko', 'KR'),
                delegates: const [
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
    const gold = Color(0xFFFFD700);

    return BaseScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const OnboardingStepLabel(current: 5, total: 5),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingHeader(
                title: '매일 일기 알림을\n보내드릴까요?',
                subtitle: '잠깐의 알림이 매일 마음을 정리하는\n작은 습관이 돼요.',
              ),
              const SizedBox(height: 36),

              // 알림 시간 카드
              GestureDetector(
                onTap: _saving ? null : _pickTime,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 18),
                  decoration: BoxDecoration(
                    color: gold.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: gold.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gold.withOpacity(0.18),
                          border: Border.all(color: gold.withOpacity(0.55)),
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: gold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '알림 시간',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '매일 같은 시간에 알려드려요',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(_hour, _minute),
                        style: const TextStyle(
                          color: gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          color: Colors.white38, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 안내 텍스트
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '언제든 [마이 → 알림 설정]에서 끄거나 시간을 바꿀 수 있어요.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ),

              const Spacer(),

              OnboardingNextButton(
                label: '알림 받기',
                enabled: !_saving,
                loading: _saving,
                onTap: _enableAndContinue,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _saving ? null : _skipAndContinue,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  height: 46,
                  alignment: Alignment.center,
                  child: Text(
                    '지금은 괜찮아요',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withOpacity(0.35),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
