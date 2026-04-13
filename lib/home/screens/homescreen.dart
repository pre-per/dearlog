import 'dart:ui';

import 'package:dearlog/app.dart';
import 'package:dearlog/call/screens/call_loading_screen.dart';
import 'package:dearlog/call/services/conversation_backup_service.dart';
import 'package:dearlog/call/services/tts_service.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:dearlog/call/providers/voice_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rippleCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  bool _hasBackup = false;
  DateTime? _backupTime;

  @override
  void initState() {
    super.initState();

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.99, end: 1.01).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _checkBackup();
  }

  Future<void> _checkBackup() async {
    final has = await ConversationBackupService.hasBackup();
    final ts = await ConversationBackupService.getTimestamp();
    if (mounted) setState(() { _hasBackup = has; _backupTime = ts; });
  }

  Future<void> _restoreAndGoLoading() async {
    final messages = await ConversationBackupService.load();
    if (messages == null || !mounted) return;
    ref.read(messageProvider.notifier).restore(messages);
    setState(() => _hasBackup = false);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CallLoadingScreen(elapsed: Duration.zero)),
    );
  }

  Future<void> _restoreAndResume() async {
    final messages = await ConversationBackupService.load();
    if (messages == null || !mounted) return;
    ref.read(messageProvider.notifier).restore(messages);
    setState(() => _hasBackup = false);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiChatScreen()),
    );
  }

  Future<void> _dismissBackup() async {
    await ConversationBackupService.clear();
    if (mounted) setState(() => _hasBackup = false);
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
              (Route<dynamic> route) => false,
            );
          },
          child: Image.asset(
            'asset/image/logo_white.png',
            width: 120,
            height: 120,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => NoticeScreen()));
            },
            icon: Icon(
              IconsaxPlusBold.notification,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
        ],
      ),

      body: userAsync.when(
        data: (user) {
          if (user == null) return AuthErrorScreen();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                if (_hasBackup)
                  _RecoveryBanner(
                    timestamp: _backupTime,
                    onDiary: _restoreAndGoLoading,
                    onResume: _restoreAndResume,
                    onDismiss: _dismissBackup,
                  ),
                if (_hasBackup) const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('MM월 dd일(E)', 'ko_KR').format(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _VoiceSelectButton(),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '당신의 목소리를 들을 준비가 되었어요',
                    style: TextStyle(
                      color: Color(0xdfffffff),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 68),
                SizedBox(
                  width: 232,
                  height: 232,
                  child: AnimatedBuilder(
                    animation: _rippleCtrl,
                    builder: (context, _) {
                      final t = _rippleCtrl.value; // 0..1

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // ✅ 파장 4개 (시차 0.00, 0.25, 0.50, 0.75)
                          _RippleRing(
                            t: (t + 0.00) % 1.0,
                            baseSize: 232,
                            minScale: 1.00,
                            maxScale: 1.40,   // 더 멀리 퍼지게
                            maxOpacity: 0.22, // 더 진하게
                            strokeWidth: 1.8, // 조금 더 두껍게
                          ),
                          _RippleRing(
                            t: (t + 0.25) % 1.0,
                            baseSize: 232,
                            minScale: 1.00,
                            maxScale: 1.40,
                            maxOpacity: 0.18,
                            strokeWidth: 1.6,
                          ),
                          _RippleRing(
                            t: (t + 0.50) % 1.0,
                            baseSize: 232,
                            minScale: 1.00,
                            maxScale: 1.40,
                            maxOpacity: 0.15,
                            strokeWidth: 1.4,
                          ),
                          _RippleRing(
                            t: (t + 0.75) % 1.0,
                            baseSize: 232,
                            minScale: 1.00,
                            maxScale: 1.40,
                            maxOpacity: 0.12,
                            strokeWidth: 1.2,
                          ),

                          ScaleTransition(
                            scale: _pulse,
                            child: Image.asset(
                              'asset/image/moon_images/grey_moon.png',
                              width: 232,
                              height: 232,
                            ),
                          ),

                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  width: 350,
                  height: 55,
                  decoration: BoxDecoration(
                    image: DecorationImage(image: AssetImage('asset/image/lang_bubble.png'))
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Text(
                    '디어로그에게 당신의 이야기를 들려주세요',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 19),
                CallStartIconbutton(),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        error: (err, _) => Center(child: Text('유저 데이터를 불러오지 못했습니다.\n오류:$err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _RecoveryBanner extends StatelessWidget {
  final DateTime? timestamp;
  final VoidCallback onDiary;
  final VoidCallback onResume;
  final VoidCallback onDismiss;

  const _RecoveryBanner({
    required this.timestamp,
    required this.onDiary,
    required this.onResume,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel = timestamp != null
        ? DateFormat('MM월 dd일 HH:mm', 'ko_KR').format(timestamp!)
        : '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: Color(0xFFFFD700), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '이전 대화 기록을 복구할까요?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onDismiss,
                    child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.5), size: 18),
                  ),
                ],
              ),
              if (timeLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  timeLabel,
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onDiary,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                        ),
                        child: const Center(
                          child: Text(
                            '일기 생성하기',
                            style: TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: onResume,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: const Center(
                          child: Text(
                            '대화 이어하기',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RippleRing extends StatelessWidget {
  final double t; // 0..1
  final double baseSize;
  final double minScale;
  final double maxScale;
  final double maxOpacity;
  final double strokeWidth;

  const _RippleRing({
    required this.t,
    required this.baseSize,
    required this.minScale,
    required this.maxScale,
    required this.maxOpacity,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(t);

    final scale = lerpDouble(minScale, maxScale, eased)!;

    // ✅ 초반에는 좀 더 보이고, 끝으로 갈수록 자연스럽게 사라지게
    final opacity = (1.0 - eased) * maxOpacity;

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: baseSize,
            height: baseSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: strokeWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceSelectButton extends ConsumerWidget {
  const _VoiceSelectButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedVoice = ref.watch(selectedVoiceProvider);

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => _VoicePickerDialog(ref: ref),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              selectedVoice ?? '목소리 선택',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _VoicePickerDialog extends StatefulWidget {
  final WidgetRef ref;
  const _VoicePickerDialog({required this.ref});

  @override
  State<_VoicePickerDialog> createState() => _VoicePickerDialogState();
}

class _VoicePickerDialogState extends State<_VoicePickerDialog> {
  static const _voices = [
    'alloy', 'ash', 'ballad', 'cedar', 'coral', 'echo',
    'fable', 'marin', 'nova', 'onyx', 'sage', 'shimmer', 'verse',
  ];

  late final TtsService _tts;
  String? _activeVoice;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tts = TtsService(apiKey: RemoteConfigService().openAIApiKey);
    _tts.init();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _preview(String voice) async {
    if (_activeVoice == voice && !_isLoading) {
      await _tts.stop();
      if (mounted) setState(() { _activeVoice = null; });
      return;
    }
    if (_activeVoice != null) await _tts.stop();
    if (!mounted) return;
    setState(() { _activeVoice = voice; _isLoading = true; });
    try {
      _tts.voice = voice;
      await _tts.speakAndWait(
        '안녕, 반가워',
        onPlaybackStart: () {
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      debugPrint('[PREVIEW] $e');
    } finally {
      if (mounted) setState(() { _activeVoice = null; _isLoading = false; });
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final selectedVoice = widget.ref.watch(selectedVoiceProvider);

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'AI 목소리 선택',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 360,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _voices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final voice = _voices[index];
                  final isSelected = selectedVoice == voice;
                  final isActive = _activeVoice == voice;
                  final isLoadingThis = isActive && _isLoading;
                  final isPlayingThis = isActive && !_isLoading;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.15)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFFD700).withOpacity(0.7)
                            : Colors.white.withOpacity(0.08),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // 선택 영역
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              widget.ref.read(selectedVoiceProvider.notifier).state = voice;
                              _tts.stop();
                              Navigator.pop(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? const Color(0xFFFFD700)
                                          : Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _capitalize(voice),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 미리듣기 버튼
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _preview(voice),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPlayingThis
                                    ? const Color(0xFFFFD700).withOpacity(0.15)
                                    : Colors.white.withOpacity(0.07),
                                border: Border.all(
                                  color: isPlayingThis
                                      ? const Color(0xFFFFD700).withOpacity(0.5)
                                      : Colors.white.withOpacity(0.12),
                                ),
                              ),
                              child: isLoadingThis
                                  ? Padding(
                                      padding: const EdgeInsets.all(9),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                    )
                                  : Icon(
                                      isPlayingThis ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                      size: 18,
                                      color: isPlayingThis
                                          ? const Color(0xFFFFD700)
                                          : Colors.white.withOpacity(0.5),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
