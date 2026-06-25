import 'dart:async';
import 'dart:ui';
import 'package:dearlog/call/services/conversation_backup_service.dart';
import 'package:dearlog/call/services/tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dearlog/app.dart';
import 'package:dearlog/call/providers/voice_provider.dart';
import 'package:dearlog/core/safety/crisis_support.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final _textController = TextEditingController();
  
  // ✅ initState에서 초기화하기 위해 late 사용
  late final TtsService _tts;
  bool _isSpeaking = false;
  final FocusNode _inputFocus = FocusNode();
  bool _sending = false;

  bool _sessionActive = true;
  bool _startingListening = false;

  Timer? _timer;
  Duration _elapsedAccum = Duration.zero;
  DateTime? _runningSince;

  bool _isPaused = false;
  bool _isTextMode = false;

  /// STT 오인식 수정 모드 — null 이 아니면 현재 그 인덱스의 유저 말풍선을 편집 중.
  int? _editingIndex;
  final TextEditingController _editingTextController = TextEditingController();
  final FocusNode _editingFocusNode = FocusNode();

  bool get _isEditing => _editingIndex != null;

  /// 통화 중 강제 종료 대비 자동 백업의 throttle. 너무 잦은 저장을 막기 위함.
  DateTime? _lastBackupSavedAt;
  int _lastBackedUpMessageCount = 0;

  Duration get _currentElapsed {
    if (_runningSince == null) return _elapsedAccum;
    return _elapsedAccum + DateTime.now().difference(_runningSince!);
  }

  @override
  void initState() {
    super.initState();
    
    // ✅ 선택한 목소리 + 배속 가져와서 TTS 서비스 초기화
    final selectedVoice = ref.read(selectedVoiceProvider);
    final selectedSpeed = ref.read(selectedSpeedProvider);
    _tts = TtsService(
      apiKey: RemoteConfigService().openAIApiKey,
      voice: selectedVoice,
      speedMultiplier: selectedSpeed,
    );
    _tts.init();

    _runningSince = DateTime.now();

    // CBT 지표 — 통화 세션 시작 (= 녹음 시작).
    // ignore: unawaited_futures
    AnalyticsService.logCallStarted();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_runningSince != null) {
        setState(() {});
      }
    });

    _ensureSpeechAndStart();
  }

  /// 메시지 변화 시 호출 — 새 메시지가 추가됐고 마지막 저장 후 5초 이상 흘렀으면
  /// 백업을 저장한다. (메시지 수 증가가 없으면 노op — streaming 업데이트 등은 무시)
  void _maybeSaveBackup(List<Message> messages) {
    final realCount =
        messages.where((m) => m.content != '__loading__').length;
    if (realCount <= 1) return; // 첫 인사만 있으면 저장 가치 없음
    if (realCount <= _lastBackedUpMessageCount) return;

    final now = DateTime.now();
    if (_lastBackupSavedAt != null &&
        now.difference(_lastBackupSavedAt!).inSeconds < 5) {
      return;
    }
    _lastBackupSavedAt = now;
    _lastBackedUpMessageCount = realCount;

    // fire-and-forget — 백업 실패는 무시 (UX 영향 X)
    ConversationBackupService.save(messages).catchError((_) {});
  }

  Future<void> _ensureSpeechAndStart() async {
    debugPrint('[CALL] _ensureSpeechAndStart: 시작');
    final speech = ref.read(speechNotifierProvider.notifier);
    await speech.ensureInitialized();
    final s = ref.read(speechNotifierProvider);
    debugPrint('[CALL] _ensureSpeechAndStart: ensureInitialized 완료 (isAvailable=${s.isAvailable})');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 800));
      debugPrint('[CALL] _ensureSpeechAndStart: 800ms 대기 후 _startListeningSafely 호출');
      await _startListeningSafely();
    });
  }

  @override
  void dispose() {
    _sessionActive = false;
    _inputFocus.dispose();
    _editingFocusNode.dispose();
    _timer?.cancel();
    _timer = null;
    _scrollController.dispose();
    _textController.dispose();
    _editingTextController.dispose();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _startListeningSafely() async {
    debugPrint('[CALL] _startListeningSafely: 진입 (sessionActive=$_sessionActive, paused=$_isPaused, textMode=$_isTextMode, editing=$_isEditing, starting=$_startingListening)');
    if (!_sessionActive || _isPaused || _isTextMode || _isEditing) {
      debugPrint('[CALL] _startListeningSafely: ⚠️ 세션/모드 조건 불충족 → 반환');
      return;
    }
    if (_startingListening) {
      debugPrint('[CALL] _startListeningSafely: ⚠️ 이미 시작 중 → 반환');
      return;
    }

    _startingListening = true;
    try {
      final speech = ref.read(speechNotifierProvider.notifier);
      final currentState = ref.read(speechNotifierProvider);
      debugPrint('[CALL] _startListeningSafely: 현재 state(isAvailable=${currentState.isAvailable}, isRecording=${currentState.isRecording})');

      if (currentState.isRecording) {
        debugPrint('[CALL] _startListeningSafely: ⚠️ 이미 isRecording=true → 반환');
        return;
      }

      await speech.ensureInitialized();

      bool started = false;
      for (int i = 0; i < 3; i++) {
        final s = ref.read(speechNotifierProvider);
        debugPrint('[CALL] _startListeningSafely: retry #$i (isAvailable=${s.isAvailable})');
        if (s.isAvailable) {
          speech.enableContinuous();
          await speech.startListening(_sendText);
          final after = ref.read(speechNotifierProvider);
          debugPrint('[CALL] _startListeningSafely: startListening 후 (isRecording=${after.isRecording})');
          started = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (!started) {
        debugPrint("[CALL] _startListeningSafely: ❌ 마이크 엔진을 시작할 수 없습니다 (isAvailable이 끝까지 false).");
      }
    } catch (e, st) {
      debugPrint("[CALL] _startListeningSafely: ❌ 예외: $e\n$st");
    } finally {
      _startingListening = false;
      debugPrint('[CALL] _startListeningSafely: 종료');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      await Future.delayed(const Duration(milliseconds: 60));
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _sendText(String text) async {
    if (!_sessionActive || _sending) return;
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    _sending = true;
    try {
      // 마이크 중지
      final speech = ref.read(speechNotifierProvider.notifier);
      speech.disableContinuous();
      await speech.stopListening();

      // 유저 메시지 추가 (__loading__ placeholder 포함)
      final notifier = ref.read(messageProvider.notifier);
      notifier.addUserMessage(cleaned);
      _scrollToBottom();

      // 자살·자해 등 위기 신호가 보이면 전문기관 안내 (대화는 막지 않는다)
      // ignore: unawaited_futures
      CrisisSupport.maybeShowSupport(context, cleaned);

      // 사용자 프로필 + 최근 일기 3개 — 익명화된 컨텍스트로 친구 톤 유지.
      final profile = ref.read(userProfileProvider);
      final userId = ref.read(userIdProvider);
      List<DiaryEntry> recentDiaries = const [];
      if (userId != null) {
        try {
          recentDiaries = await ref
              .read(diaryRepositoryProvider)
              .fetchRecentDiaries(userId, limit: 3);
        } catch (_) {
          // 컨텍스트 fetch 실패해도 통화는 계속.
        }
      }

      // GPT 응답을 한 번에 받는다 (이전: 토큰 스트리밍 + 문장 단위 TTS).
      //   문장 단위로 TTS 를 호출하면 supertonic 추론 또는 OpenAI HTTP RTT
      //   사이에 짧은 무음이 끼어 "어눌하게" 들리는 문제가 있어서, 응답을
      //   다 받은 뒤 한 번에 합성/재생한다. 응답 표시도 한 번에 갱신.
      final messages = ref
          .read(messageProvider)
          .where((m) => m.content != '__loading__')
          .toList();

      String reply;
      try {
        final response = await OpenAIService().getChatResponse(
          messages,
          profile: profile,
          recentDiaries: recentDiaries,
        );
        reply = response.message.content.trim();
        if (reply.isEmpty) reply = '죄송해요, 응답하지 못했어요.';
      } catch (e) {
        debugPrint('[SEND_TEXT] GPT 호출 오류: $e');
        reply = '죄송해요. 잠시 후 다시 시도해 주세요.';
      }

      if (!_sessionActive) return;

      notifier.updateStreaming(reply);
      _scrollToBottom();

      // TTS — 응답 전체를 한 번에 합성/재생.
      if (!_isPaused && !_isTextMode && !_isEditing && reply.isNotEmpty) {
        if (mounted) setState(() => _isSpeaking = true);
        try {
          final bytes = await _tts.fetchAudio(reply);
          if (_sessionActive &&
              !_isPaused &&
              !_isTextMode &&
              !_isEditing &&
              bytes.isNotEmpty) {
            await _tts.playAudio(bytes);
          }
        } catch (e) {
          debugPrint('[TTS] ❌ $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AI 음성 재생에 실패했어요. 잠시 후 다시 시도해 주세요.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[SEND_TEXT] 오류: $e');
      ref.read(messageProvider.notifier).updateStreaming('죄송해요. 잠시 후 다시 시도해 주세요.');
    } finally {
      _sending = false;
      if (mounted) setState(() => _isSpeaking = false);
      if (_sessionActive && !_isPaused && !_isTextMode && !_isEditing) {
        await _startListeningSafely();
      }
    }
  }

  Future<void> _onPauseToggle() async {
    final speech = ref.read(speechNotifierProvider.notifier);
    setState(() => _isPaused = !_isPaused);

    if (_isPaused) {
      if (_runningSince != null) {
        _elapsedAccum += DateTime.now().difference(_runningSince!);
        _runningSince = null;
      }
      await speech.shutdown();
    } else {
      _runningSince = DateTime.now();
      if (!_isTextMode) {
        await _startListeningSafely();
      }
    }
  }

  Future<void> _onTextToggle() async {
    final speech = ref.read(speechNotifierProvider.notifier);

    if (!_isTextMode) {
      setState(() => _isTextMode = true);
      await speech.shutdown();
      if (!mounted) return;
      _inputFocus.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isTextMode = false);

    if (!_isPaused) {
      await _startListeningSafely();
    }
  }

  /// 유저 말풍선 길게 누름 → STT 오인식 수정 모드 진입.
  /// 통화는 일시정지(STT/TTS/타이머 모두 멈춤). AI 재응답은 일으키지 않는다.
  Future<void> _enterEditMode(int index) async {
    if (!_sessionActive) return;
    if (_isEditing) return;

    final messages = ref.read(messageProvider);
    if (index < 0 || index >= messages.length) return;
    if (messages[index].role != 'user') return;

    // AI 음성 즉시 중단 + STT 종료 + 타이머 멈춤
    await _tts.stop();
    await ref.read(speechNotifierProvider.notifier).shutdown();

    if (_runningSince != null) {
      _elapsedAccum += DateTime.now().difference(_runningSince!);
      _runningSince = null;
    }

    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _editingIndex = index;
      _editingTextController.text = messages[index].content;
      _editingTextController.selection = TextSelection.collapsed(
        offset: _editingTextController.text.length,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editingFocusNode.requestFocus();
    });
  }

  Future<void> _commitEdit() async {
    final newText = _editingTextController.text.trim();
    if (newText.isEmpty) return; // 완료 버튼이 비활성화돼 있어 도달 안 함, 방어용
    final index = _editingIndex;
    if (index == null) return;

    ref.read(messageProvider.notifier).updateUserMessage(index, newText);
    await _exitEditMode();
  }

  Future<void> _cancelEdit() async {
    if (!_isEditing) return;
    await _exitEditMode();
  }

  /// 편집 종료 — 통화는 자동으로 재개(편집 진입 전 paused/textMode 였다면 그 상태 유지).
  Future<void> _exitEditMode() async {
    if (!_isEditing) return;

    // FocusScope.unfocus() 는 _editingFocusNode 뿐 아니라 부모 트리의 모든 focus
    // (예: 텍스트 모드의 _inputFocus) 까지 풀어버린다. 텍스트 모드로 복귀할
    // 때는 아래에서 다시 _inputFocus.requestFocus() 로 키보드를 띄워야 한다.
    if (mounted) FocusScope.of(context).unfocus();

    setState(() {
      _editingIndex = null;
      _editingTextController.clear();
    });

    // 편집은 일시적 pause — _isPaused 자체는 안 건드렸으니 그 값을 신뢰.
    if (!_isPaused && _sessionActive) {
      _runningSince = DateTime.now();
      if (_isTextMode) {
        // 텍스트 모드면 키보드 포커스를 다시 잡아 입력이 가능하게 한다.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isTextMode && !_isEditing) {
            _inputFocus.requestFocus();
          }
        });
      } else {
        // _enterEditMode 의 shutdown() 직후 즉시 listen() 을 호출하면
        // speech_to_text 내부 상태가 미처 정리되지 않아 listen 이 silently
        // 무시되는 경우가 있다. 짧게 텀을 두고 재진입.
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        if (!_sessionActive || _isPaused || _isTextMode || _isEditing) return;
        await _startListeningSafely();
      }
    }
    if (mounted) setState(() {});
  }

  /// [DEBUG ONLY] 일기 생성 실패 상황을 시뮬레이션
  Future<void> _debugForceFailure() async {
    _sessionActive = false;
    _timer?.cancel();
    _timer = null;
    await ref.read(speechNotifierProvider.notifier).shutdown();
    await _tts.stop();

    final messages = ref.read(messageProvider);
    await ConversationBackupService.save(messages);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainScreen(snackMessage: '[DEBUG] 강제 실패 — 복구 배너를 확인하세요.'),
      ),
      (route) => false,
    );
  }

  Future<void> _onCallEnd() async {
    // 사용자가 한마디도 안 했으면 (=user role 메시지 0) 일기를 만들 거리가 없다.
    // OpenAI 토큰만 낭비되므로 일기 생성 없이 메인으로 안내한다.
    final userSaidSomething = ref
        .read(messageProvider)
        .any((m) => m.role == 'user' && m.content.trim().isNotEmpty);

    if (!userSaidSomething) {
      final confirmEnd = await showGlassDialog<bool>(
        context: context,
        title: '아직 대화를 시작하지 않았어요',
        message: '대화가 없으면 일기를 만들 수 없어요.\n그대로 통화를 종료할까요?',
        actions: const [
          GlassDialogAction(label: '계속 대화하기', value: false),
          GlassDialogAction(label: '통화 종료', value: true, isDestructive: true),
        ],
      );
      if (confirmEnd != true) return;

      _sessionActive = false;
      _timer?.cancel();
      _timer = null;
      await ref.read(speechNotifierProvider.notifier).shutdown();
      await _tts.stop();

      // 통화 길이는 기록하되 messageCount=0 으로 — 분석상 "빈 통화" 로 구분.
      // ignore: unawaited_futures
      AnalyticsService.logCallEnded(
        durationSeconds: _currentElapsed.inSeconds,
        messageCount: 0,
      );

      // 백업이 남아있을 수 있으면 정리 — 다음 통화에서 빈 백업으로 복구 배너가
      // 뜨지 않도록.
      await ConversationBackupService.clear();
      ref.read(messageProvider.notifier).clear();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainScreen()),
        (route) => false,
      );
      return;
    }

    _sessionActive = false;
    _timer?.cancel();
    _timer = null;
    await ref.read(speechNotifierProvider.notifier).shutdown();
    await _tts.stop();

    // CBT 지표 — 통화 세션 종료 (= 녹음 길이).
    // __loading__ placeholder 는 메시지 카운트에서 제외.
    final elapsed = _currentElapsed;
    final messageCount = ref
        .read(messageProvider)
        .where((m) => m.content != '__loading__')
        .length;
    // ignore: unawaited_futures
    AnalyticsService.logCallEnded(
      durationSeconds: elapsed.inSeconds,
      messageCount: messageCount,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallLoadingScreen(
          elapsed: elapsed,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messageProvider);
    final speechState = ref.watch(speechNotifierProvider);

    // 통화 중 메시지가 늘어날 때마다 (throttle 5초) 백업 저장 →
    // 사용자가 통화 도중 앱을 강제 종료해도 다음 진입에서 복구 배너로 복원 가능.
    ref.listen<List<Message>>(messageProvider, (prev, next) {
      _maybeSaveBackup(next);
    });

    return Stack(
      children: [
        BaseScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 40,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'asset/icons/call/timer.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(Color(0x80ffffff), BlendMode.srcIn),
            ),
            const SizedBox(width: 6),
            Text(
              _formatDuration(_currentElapsed),
              style: const TextStyle(
                color: Color(0x80ffffff),
                fontFamily: 'Alumni',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          if (kDebugMode)
            GestureDetector(
              onTap: _debugForceFailure,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.6)),
                ),
                child: const Text(
                  'FAIL',
                  style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)..copyWith(bottom: _bottomAreaHeight(context)),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                return MessageBubble(
                  message: m,
                  onLongPress: (m.role == 'user' && !_isEditing)
                      ? () => _enterEditMode(index)
                      : null,
                );
              },
            ),
          ),
          SizedBox(height: _bottomAreaHeight(context) + MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
      bottomNavigationBar: _isEditing
          ? null
          : AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isTextMode)
                _TextInputBar(
                  controller: _textController,
                  focusNode: _inputFocus,
                  onSend: (v) async {
                    await _sendText(v);
                    _textController.clear();
                  },
                  onClose: _onTextToggle,
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: _MicStatusPanel(
                    isSessionActive: _sessionActive,
                    isPaused: _isPaused,
                    isTextMode: _isTextMode,
                    isSpeaking: _isSpeaking,
                    isRecording: speechState.isRecording,
                    liveText: speechState.currentText,
                  ),
                ),
              SizedBox(
                height: 150,
                width: double.infinity,
                child: CallFuncIsland(
                  onPauseToggle: _onPauseToggle,
                  onTextToggle: _onTextToggle,
                  onCallEnd: _onCallEnd,
                  isTextMode: _isTextMode,
                  isPaused: _isPaused,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
        ),
        if (_isEditing) Positioned.fill(child: _buildEditOverlay()),
      ],
    );
  }

  Widget _buildEditOverlay() {
    final mq = MediaQuery.of(context);
    final keyboardHeight = mq.viewInsets.bottom;
    final canCommit = _editingTextController.text.trim().isNotEmpty;

    // Material ancestor 가 없으면 TextField/Text 가 깨지므로 transparency Material 로 감싼다.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 블러 + 어두운 오버레이 — 탭하면 취소
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _cancelEdit,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: ColoredBox(color: Colors.black.withOpacity(0.45)),
              ),
            ),
          ),
        // 플로팅 편집 말풍선 + 액션 버튼 — 키보드 위쪽
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          left: 24,
          right: 24,
          bottom: keyboardHeight + mq.padding.bottom + 24,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // 블러 onTap 으로 전파되지 않게 흡수
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: mq.size.width * 0.82,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _editingTextController,
                      focusNode: _editingFocusNode,
                      autofocus: true,
                      maxLines: null,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      cursorColor: Colors.black87,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'GowunBatang',
                        height: 1.35,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: '내용을 수정해 주세요',
                        hintStyle: TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontFamily: 'GowunBatang',
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _editAction('취소', onTap: _cancelEdit, secondary: true),
                    const SizedBox(width: 10),
                    _editAction('완료', onTap: canCommit ? _commitEdit : null),
                  ],
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _editAction(String label,
      {VoidCallback? onTap, bool secondary = false}) {
    final disabled = onTap == null;
    final fg = secondary
        ? Colors.white.withOpacity(0.9)
        : (disabled
            ? Colors.white.withOpacity(0.45)
            : const Color(0xFFFFD964));
    final bg = secondary
        ? Colors.white.withOpacity(0.10)
        : (disabled
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFFFD964).withOpacity(0.18));
    final border = secondary
        ? Colors.white.withOpacity(0.18)
        : (disabled
            ? Colors.white.withOpacity(0.10)
            : const Color(0xFFFFD964).withOpacity(0.42));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: 'GowunBatang',
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  double _bottomAreaHeight(BuildContext context) {
    final extra = _isTextMode ? 80.0 : 120.0;
    return 150 + 12 + extra + MediaQuery.of(context).padding.bottom;
  }
}

class _MicStatusPanel extends StatelessWidget {
  final bool isSessionActive;
  final bool isPaused;
  final bool isTextMode;
  final bool isSpeaking;
  final bool isRecording;
  final String liveText;

  const _MicStatusPanel({
    required this.isSessionActive,
    required this.isPaused,
    required this.isTextMode,
    required this.isSpeaking,
    required this.isRecording,
    required this.liveText,
  });

  @override
  Widget build(BuildContext context) {
    final shouldShow = isSessionActive && !isTextMode && !isPaused;
    final showSpeaking = shouldShow && isSpeaking;
    if (!shouldShow) return const SizedBox.shrink();

    final titleText = showSpeaking ? 'AI가 말하는 중...' : (isRecording ? '말씀하세요...' : '마이크 준비 중...');
    final guideText = showSpeaking ? '말이 끝나면 자동으로 다시 들을게요.' : (isRecording ? '지금 말한 내용이 아래에 실시간으로 표시돼요.' : '잠시만 기다려 주세요.');
    final displayText = liveText.trim().isEmpty ? (showSpeaking ? '' : '…') : liveText.trim();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusDot(active: showSpeaking ? true : isRecording),
              const SizedBox(width: 10),
              Expanded(child: Text(titleText, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 14, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(999)),
                child: Text(showSpeaking ? 'TTS' : (isRecording ? 'REC' : 'WAIT'), style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(guideText, style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12)),
          const SizedBox(height: 10),
          if (!showSpeaking)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0x12FFFFFF), borderRadius: BorderRadius.circular(14)),
              child: Text(displayText, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 14, height: 1.25)),
            ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;
  const _StatusDot({required this.active});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: active ? const Color(0xFFFFFFFF) : const Color(0x66FFFFFF)),
    );
  }
}

class _TextInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function(String) onSend;
  final VoidCallback onClose;
  const _TextInputBar({required this.controller, required this.focusNode, required this.onSend, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x22FFFFFF))),
        child: Row(
          children: [
            GestureDetector(
              onTap: onClose,
              child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.close, color: Color(0xCCFFFFFF), size: 20)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (v) async => await onSend(v),
                style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 14),
                decoration: const InputDecoration(hintText: '키보드로 입력해 보세요…', hintStyle: TextStyle(color: Color(0x80FFFFFF)), border: InputBorder.none, isDense: true),
              ),
            ),
            GestureDetector(
              onTap: () async => await onSend(controller.text),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(14)),
                child: const Text('전송', style: TextStyle(color: Color(0xE6FFFFFF), fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
