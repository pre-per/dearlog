import 'package:dearlog/app.dart';

/// 회원가입 3단계 — 나잇대.
class OnboardingAgeGroupScreen extends ConsumerStatefulWidget {
  const OnboardingAgeGroupScreen({super.key});

  @override
  ConsumerState<OnboardingAgeGroupScreen> createState() =>
      _OnboardingAgeGroupScreenState();
}

class _OnboardingAgeGroupScreenState
    extends ConsumerState<OnboardingAgeGroupScreen> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingDraftProvider);
    _selected = draft.ageGroup.isEmpty ? null : draft.ageGroup;
  }

  void _next() {
    ref.read(onboardingDraftProvider.notifier).state =
        ref.read(onboardingDraftProvider).copyWith(ageGroup: _selected!);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingInterestsScreen()),
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
        title: const OnboardingStepLabel(current: 3, total: 5),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingHeader(
                title: '나잇대를 알려주세요.',
                subtitle: '정확한 나이는 묻지 않아요.\n또래 톤으로 대화를 맞추기 위해서만 사용돼요.',
              ),
              const SizedBox(height: 28),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.6,
                  children: kAgeGroupOptions
                      .map((a) => _AgeTile(
                            label: a,
                            selected: _selected == a,
                            onTap: () => setState(() => _selected = a),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
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
}

class _AgeTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AgeTile({
    required this.label,
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
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? gold : Colors.white.withOpacity(0.88),
              fontSize: 16,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
