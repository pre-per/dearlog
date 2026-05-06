import 'package:dearlog/app.dart';

/// 회원가입 1단계 — 닉네임.
class OnboardingNameScreen extends ConsumerStatefulWidget {
  const OnboardingNameScreen({super.key});

  @override
  ConsumerState<OnboardingNameScreen> createState() =>
      _OnboardingNameScreenState();
}

class _OnboardingNameScreenState extends ConsumerState<OnboardingNameScreen> {
  final TextEditingController _controller = TextEditingController();
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    // 디버그 진입 등으로 다시 들어오면 이전 값 복원
    final draft = ref.read(onboardingDraftProvider);
    _controller.text = draft.nickname;
    _nickname = draft.nickname;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid {
    final regex = RegExp(r'^[가-힣a-zA-Z0-9._]{1,12}$');
    return regex.hasMatch(_nickname);
  }

  void _clear() {
    _controller.clear();
    setState(() => _nickname = '');
  }

  void _next() {
    ref.read(onboardingDraftProvider.notifier).state =
        ref.read(onboardingDraftProvider).copyWith(nickname: _nickname);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingGenderScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const _StepLabel(current: 1, total: 4),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '디어로그에서 사용할\n이름을 입력해주세요.',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                '공백 없이 12자 이하,\n기호는 _ . 만 사용 가능합니다.',
                style: TextStyle(
                    color: Colors.white70, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _controller,
                onChanged: (val) => setState(() => _nickname = val),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  hintText: '닉네임 입력',
                  hintStyle:
                      TextStyle(color: Colors.white.withOpacity(0.4)),
                  suffixIcon: _nickname.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.cancel,
                              color: Colors.white.withOpacity(0.6)),
                          onPressed: _clear,
                        )
                      : null,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFFFD700), width: 1.5),
                  ),
                  counterStyle:
                      TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                maxLength: 12,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              const Spacer(),
              OnboardingNextButton(
                label: '다음',
                enabled: _isValid,
                onTap: _next,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 공통 위젯 — 다른 온보딩 화면도 재사용
// ─────────────────────────────────────────────────

/// 상단 단계 라벨 (예: "1 / 4").
class _StepLabel extends StatelessWidget {
  final int current;
  final int total;
  const _StepLabel({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$current',
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          ' / $total',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 모든 온보딩 화면 하단의 큰 다음/완료 버튼.
class OnboardingNextButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  const OnboardingNextButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD700);
    return GestureDetector(
      onTap: (enabled && !loading) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: enabled
              ? gold.withOpacity(0.22)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? gold.withOpacity(0.6)
                : Colors.white.withOpacity(0.12),
            width: 1.4,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: gold.withOpacity(0.18),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(gold),
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: enabled ? gold : Colors.white.withOpacity(0.45),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 큰 헤더(제목 + 부제) — 모든 온보딩 화면 상단 공통.
class OnboardingHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const OnboardingHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.4,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// 다른 온보딩 화면들이 import 안 해도 되도록 공통 위젯 export.
/// (BaseScaffold/AppBar 위에 1/4, 2/4 ... 표기)
class OnboardingStepLabel extends StatelessWidget {
  final int current;
  final int total;
  const OnboardingStepLabel(
      {super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) =>
      _StepLabel(current: current, total: total);
}
