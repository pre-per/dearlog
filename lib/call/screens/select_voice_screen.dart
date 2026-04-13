import 'package:dearlog/app.dart';
import 'package:dearlog/call/providers/voice_provider.dart';
import 'package:dearlog/call/screens/ai_chat_screen.dart';
import 'package:dearlog/call/services/tts_service.dart';

class SelectVoiceScreen extends ConsumerStatefulWidget {
  const SelectVoiceScreen({super.key});

  @override
  ConsumerState<SelectVoiceScreen> createState() => _SelectVoiceScreenState();
}

class _SelectVoiceScreenState extends ConsumerState<SelectVoiceScreen> {
  static const List<String> _voices = [
    'alloy', 'ash', 'ballad', 'cedar', 'coral', 'echo',
    'fable', 'marin', 'nova', 'onyx', 'sage', 'shimmer', 'verse',
  ];

  late final TtsService _tts;

  // 현재 로딩/재생 중인 목소리
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
    // 이미 재생 중이면 정지
    if (_activeVoice == voice && !_isLoading) {
      await _tts.stop();
      if (mounted) setState(() { _activeVoice = null; _isLoading = false; });
      return;
    }

    // 다른 목소리 재생 중이면 먼저 정지
    if (_activeVoice != null) {
      await _tts.stop();
    }

    if (!mounted) return;
    setState(() { _activeVoice = voice; _isLoading = true; });

    try {
      _tts.voice = voice;
      await _tts.speakAndWait(
        '안녕, 반가워',
        onPlaybackStart: () {
          // HTTP 다운로드 완료 → 로딩 스피너 → 정지 버튼으로 전환
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      debugPrint('[PREVIEW] TTS 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('미리듣기에 실패했어요'),
            backgroundColor: Color(0xFF333333),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() { _activeVoice = null; _isLoading = false; });
    }
  }

  void _startCall() {
    _tts.stop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AiChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedVoice = ref.watch(selectedVoiceProvider);

    return BaseScaffold(
      appBar: AppBar(
        title: const Text(
          'AI 목소리 선택',
          style: TextStyle(color: Colors.white, fontFamily: 'GowunBatang'),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              itemCount: _voices.length,
              itemBuilder: (context, index) {
                final voice = _voices[index];
                final isSelected = selectedVoice == voice;
                final isActive = _activeVoice == voice;
                final isLoadingThis = isActive && _isLoading;
                final isPlayingThis = isActive && !_isLoading;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFFD700).withOpacity(0.6)
                          : Colors.white.withOpacity(0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // ── 선택 영역 (이름) ──────────────────────────────
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            ref.read(selectedVoiceProvider.notifier).state = voice;
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 15,
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? const Color(0xFFFFD700)
                                        : Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  _capitalize(voice),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.7),
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── 미리듣기 버튼 ─────────────────────────────────
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _preview(voice),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isPlayingThis
                                  ? const Color(0xFFFFD700).withOpacity(0.15)
                                  : Colors.white.withOpacity(0.07),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isPlayingThis
                                    ? const Color(0xFFFFD700).withOpacity(0.5)
                                    : Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: isLoadingThis
                                ? Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  )
                                : Icon(
                                    isPlayingThis
                                        ? Icons.stop_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 20,
                                    color: isPlayingThis
                                        ? const Color(0xFFFFD700)
                                        : Colors.white.withOpacity(0.55),
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

          // ── 통화 시작 버튼 ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(context).padding.bottom + 16,
            ),
            child: GestureDetector(
              onTap: _startCall,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.5),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${_capitalize(selectedVoice)} 목소리로 통화 시작',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
