import 'package:dearlog/app.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 회원가입 4단계(마지막) — 관심사.
///
/// 추천 16개 아이콘 그리드 + "직접 추가" 슬롯. 최대 3개 선택.
/// 마지막 화면이므로 여기서 모든 정보를 한 번에 [UserRepository.saveProfile] 로 저장.
class OnboardingInterestsScreen extends ConsumerStatefulWidget {
  const OnboardingInterestsScreen({super.key});

  @override
  ConsumerState<OnboardingInterestsScreen> createState() =>
      _OnboardingInterestsScreenState();
}

class _OnboardingInterestsScreenState
    extends ConsumerState<OnboardingInterestsScreen> {
  /// 추천 + 사용자가 직접 추가한 항목들. 화면에서 같이 그려짐.
  late List<_Interest> _options;

  /// 선택된 라벨들. 최대 3개.
  late Set<String> _selected;

  bool _saving = false;

  static const _maxPick = 3;

  @override
  void initState() {
    super.initState();
    _options = List<_Interest>.from(_recommended);
    final draft = ref.read(onboardingDraftProvider);
    _selected = Set<String>.from(draft.interests);

    // draft에 추천 외 직접입력이 남아있으면 옵션에도 추가해서 표시되게 함.
    for (final i in draft.interests) {
      if (!_options.any((o) => o.label == i)) {
        _options.add(_Interest(label: i, icon: Icons.star_rounded));
      }
    }
  }

  void _toggle(String label) {
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else {
        if (_selected.length >= _maxPick) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black.withOpacity(0.7),
              content: const Text(
                '관심사는 최대 3개까지 선택할 수 있어요',
                style: TextStyle(color: Colors.white),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _selected.add(label);
      }
    });
  }

  Future<void> _addCustom() async {
    final result = await showGlassInputDialog(
      context: context,
      title: '관심사 직접 추가',
      hintText: '예: 보드게임',
      maxLength: 8,
    );
    if (result == null) return;
    if (_options.any((o) => o.label == result)) {
      // 이미 추천 안에 있으면 그것을 선택 처리.
      _toggle(result);
      return;
    }
    setState(() {
      _options.add(_Interest(label: result, icon: Icons.star_rounded));
      if (_selected.length < _maxPick) _selected.add(result);
    });
  }

  Future<void> _finish() async {
    if (_saving) return;
    final draftNotifier = ref.read(onboardingDraftProvider.notifier);
    draftNotifier.state =
        ref.read(onboardingDraftProvider).copyWith(interests: _selected.toList());

    final draft = ref.read(onboardingDraftProvider);

    // 디버그 진입(홈에서 디버그 버튼)이면 실제 저장 스킵 + 스낵바 + pop.
    if (draft.isDebugRun) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black.withOpacity(0.7),
          content: Text(
            '디버그 모드 — 저장하지 않았어요\n'
            '닉네임=${draft.nickname} · 성별=${draft.gender} · '
            '나잇대=${draft.ageGroup} · 관심사=${draft.interests.join(", ")}',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      // 진입 전 화면(홈)으로 모두 pop. AgreementScreen 위에 쌓인 모든 것 제거.
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }

    setState(() => _saving = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('로그인 정보가 없어요. 다시 로그인해주세요.');
      }
      final repo = ref.read(userRepositoryProvider);
      await repo.saveProfile(
        userId,
        UserProfile(
          nickname: draft.nickname,
          gender: draft.gender,
          ageGroup: draft.ageGroup,
          interests: draft.interests,
        ),
      );
      await repo.updateIsCompleted(userId, true);

      // userProvider 캐시를 무효화해서 메인에서 새 프로필이 즉시 반영되게.
      ref.invalidate(userProvider);

      // 다 끝났으니 임시 draft 비움 (다음에 디버그로 다시 들어와도 깨끗하게)
      draftNotifier.state = const OnboardingDraft();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canFinish = _selected.isNotEmpty && !_saving;

    return BaseScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const OnboardingStepLabel(current: 4, total: 4),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingHeader(
                title: '관심사를 알려주세요.',
                subtitle: '최대 3개까지 고를 수 있어요.\n원하는 게 없다면 직접 추가해도 돼요.',
              ),
              const SizedBox(height: 12),
              _SelectedCounter(count: _selected.length, max: _maxPick),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: _options.length + 1, // +1 = 직접 추가 버튼
                  itemBuilder: (context, i) {
                    if (i == _options.length) {
                      return _AddCustomTile(onTap: _addCustom);
                    }
                    final opt = _options[i];
                    return _InterestTile(
                      label: opt.label,
                      icon: opt.icon,
                      selected: _selected.contains(opt.label),
                      onTap: () => _toggle(opt.label),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              OnboardingNextButton(
                label: '시작하기',
                enabled: canFinish,
                loading: _saving,
                onTap: _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 추천 16개 (라벨 + 아이콘)
// ─────────────────────────────────────────────────

class _Interest {
  final String label;
  final IconData icon;
  const _Interest({required this.label, required this.icon});
}

const List<_Interest> _recommended = [
  _Interest(label: '음악', icon: Icons.music_note_rounded),
  _Interest(label: '영화·드라마', icon: Icons.movie_creation_outlined),
  _Interest(label: '운동', icon: Icons.fitness_center_rounded),
  _Interest(label: '러닝', icon: Icons.directions_run_rounded),
  _Interest(label: '독서', icon: Icons.menu_book_rounded),
  _Interest(label: '게임', icon: Icons.sports_esports_rounded),
  _Interest(label: '여행', icon: Icons.flight_takeoff_rounded),
  _Interest(label: '요리', icon: Icons.restaurant_rounded),
  _Interest(label: '카페', icon: Icons.local_cafe_rounded),
  _Interest(label: '패션', icon: Icons.checkroom_rounded),
  _Interest(label: '반려동물', icon: Icons.pets_rounded),
  _Interest(label: '그림', icon: Icons.brush_rounded),
  _Interest(label: '글쓰기', icon: Icons.edit_note_rounded),
  _Interest(label: '식물', icon: Icons.local_florist_rounded),
  _Interest(label: '사진', icon: Icons.camera_alt_rounded),
  _Interest(label: '명상', icon: Icons.self_improvement_rounded),
];

// ─────────────────────────────────────────────────
// 위젯들
// ─────────────────────────────────────────────────

class _InterestTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _InterestTile({
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
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: selected ? gold : Colors.white.withOpacity(0.78),
                      size: 24),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : Colors.white.withOpacity(0.85),
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.check_circle_rounded,
                    color: gold, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddCustomTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCustomTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            style: BorderStyle.solid,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded,
                color: Colors.white.withOpacity(0.7), size: 24),
            const SizedBox(height: 6),
            Text(
              '직접 추가',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedCounter extends StatelessWidget {
  final int count;
  final int max;
  const _SelectedCounter({required this.count, required this.max});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded,
              color: const Color(0xFFFFD700).withOpacity(0.85), size: 14),
          const SizedBox(width: 4),
          Text(
            '$count / $max 선택됨',
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
