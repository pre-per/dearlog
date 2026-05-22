import 'package:dearlog/app.dart';

/// 회원가입 2단계 — 성별.
class OnboardingGenderScreen extends ConsumerStatefulWidget {
  const OnboardingGenderScreen({super.key});

  @override
  ConsumerState<OnboardingGenderScreen> createState() =>
      _OnboardingGenderScreenState();
}

class _OnboardingGenderScreenState
    extends ConsumerState<OnboardingGenderScreen> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingDraftProvider);
    _selected = draft.gender.isEmpty ? null : draft.gender;
  }

  void _next() {
    ref.read(onboardingDraftProvider.notifier).state =
        ref.read(onboardingDraftProvider).copyWith(gender: _selected!);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingAgeGroupScreen()),
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
        title: const OnboardingStepLabel(current: 2, total: 5),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingHeader(
                title: '성별을 알려주세요.',
                subtitle: '입력하신 정보는 더 잘 맞는\n대화를 만드는 데에만 사용돼요.',
              ),
              const SizedBox(height: 36),
              ...kGenderOptions.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GenderTile(
                      label: g,
                      icon: _iconFor(g),
                      selected: _selected == g,
                      onTap: () => setState(() => _selected = g),
                    ),
                  )),
              const Spacer(),
              OnboardingNextButton(
                label: '다음',
                enabled: _selected != null,
                onTap: _next,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String gender) {
    switch (gender) {
      case '남자':
        return Icons.male_rounded;
      case '여자':
        return Icons.female_rounded;
      default:
        return Icons.lock_outline_rounded;
    }
  }
}

class _GenderTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD700);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? gold.withOpacity(0.16)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? gold.withOpacity(0.65)
                : Colors.white.withOpacity(0.12),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? gold : Colors.white.withOpacity(0.7),
                size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withOpacity(0.85),
                fontSize: 16,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const Spacer(),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: selected ? 1 : 0,
              child: const Icon(Icons.check_circle_rounded,
                  color: gold, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
