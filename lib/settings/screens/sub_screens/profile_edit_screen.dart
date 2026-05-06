import 'package:dearlog/app.dart';

/// 설정 → 내 정보 편집.
/// 회원가입 4단계에서 받은 모든 항목(닉네임/성별/나잇대/관심사)을 한 화면에서 편집.
/// 저장은 변경된 필드만 [UserRepository.saveProfile] 로 일괄 반영.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late TextEditingController _nicknameCtrl;
  late String _gender;
  late String _ageGroup;
  late List<String> _interests;
  late UserProfile _initial;
  bool _saving = false;

  static const _gold = Color(0xFFFFD700);
  static const _maxInterests = 3;

  @override
  void initState() {
    super.initState();
    final current = ref.read(userProfileProvider) ?? UserProfile.empty();
    _initial = current;
    _nicknameCtrl = TextEditingController(text: current.nickname);
    _gender = current.gender;
    _ageGroup = current.ageGroup;
    _interests = List<String>.from(current.interests);
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  bool get _nicknameValid {
    final regex = RegExp(r'^[가-힣a-zA-Z0-9._]{1,12}$');
    return regex.hasMatch(_nicknameCtrl.text.trim());
  }

  bool get _hasChanges {
    return _nicknameCtrl.text.trim() != _initial.nickname ||
        _gender != _initial.gender ||
        _ageGroup != _initial.ageGroup ||
        !_listEq(_interests, _initial.interests);
  }

  bool get _canSave => _hasChanges && _nicknameValid && !_saving;

  bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _toggleInterest(String label) {
    setState(() {
      if (_interests.contains(label)) {
        _interests.remove(label);
      } else {
        if (_interests.length >= _maxInterests) {
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
        _interests.add(label);
      }
    });
  }

  Future<void> _addCustomInterest() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('관심사 직접 추가',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 8,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '예: 보드게임',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            counterStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            enabledBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _gold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소',
                style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context, text);
            },
            child: const Text('추가',
                style: TextStyle(
                    color: _gold, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (_interests.length >= _maxInterests) {
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
    setState(() {
      if (!_interests.contains(result)) _interests.add(result);
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final userId = ref.read(userIdProvider);
      if (userId == null) throw Exception('로그인 정보가 없어요.');
      final repo = ref.read(userRepositoryProvider);
      final updated = UserProfile(
        nickname: _nicknameCtrl.text.trim(),
        gender: _gender,
        ageGroup: _ageGroup,
        interests: _interests,
      );
      await repo.saveProfile(userId, updated);
      ref.invalidate(userProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black.withOpacity(0.7),
          content: const Text(
            '내 정보가 저장됐어요',
            style: TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
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
    return BaseScaffold(
      appBar: AppBar(
        title: const Text(
          '내 정보',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            const _SectionLabel('닉네임'),
            const SizedBox(height: 8),
            _buildNicknameField(),
            const SizedBox(height: 28),
            const _SectionLabel('성별'),
            const SizedBox(height: 10),
            _buildGenderRow(),
            const SizedBox(height: 28),
            const _SectionLabel('나잇대'),
            const SizedBox(height: 10),
            _buildAgeGroupGrid(),
            const SizedBox(height: 28),
            _InterestsSectionLabel(count: _interests.length, max: _maxInterests),
            const SizedBox(height: 10),
            _buildInterestsGrid(),
            const SizedBox(height: 32),
            OnboardingNextButton(
              label: _saving ? '저장 중' : '저장',
              enabled: _canSave,
              loading: _saving,
              onTap: _save,
            ),
            const SizedBox(height: 16),
            _DataUseHint(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNicknameField() {
    return TextField(
      controller: _nicknameCtrl,
      onChanged: (_) => setState(() {}),
      maxLength: 12,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        hintText: '닉네임',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        counterStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _gold, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildGenderRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kGenderOptions.map((g) {
        return _ChoiceChip(
          label: g,
          icon: _genderIcon(g),
          selected: _gender == g,
          onTap: () => setState(() => _gender = g),
        );
      }).toList(),
    );
  }

  IconData _genderIcon(String g) {
    switch (g) {
      case '남자':
        return Icons.male_rounded;
      case '여자':
        return Icons.female_rounded;
      default:
        return Icons.lock_outline_rounded;
    }
  }

  Widget _buildAgeGroupGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 2.4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: kAgeGroupOptions.map((a) {
        return _ChoiceTile(
          label: a,
          selected: _ageGroup == a,
          onTap: () => setState(() => _ageGroup = a),
        );
      }).toList(),
    );
  }

  Widget _buildInterestsGrid() {
    final allOptions = <_Interest>[
      ..._recommended,
      // 추천 외 직접 추가했던 것들도 같이 노출 (선택 해제할 수 있게)
      ..._interests
          .where((i) => !_recommended.any((r) => r.label == i))
          .map((i) => _Interest(label: i, icon: Icons.star_rounded)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemCount: allOptions.length + 1,
      itemBuilder: (context, i) {
        if (i == allOptions.length) {
          return _AddInterestTile(onTap: _addCustomInterest);
        }
        final opt = allOptions[i];
        return _InterestGridTile(
          label: opt.label,
          icon: opt.icon,
          selected: _interests.contains(opt.label),
          onTap: () => _toggleInterest(opt.label),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────
// 작은 위젯들
// ─────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      );
}

class _InterestsSectionLabel extends StatelessWidget {
  final int count;
  final int max;
  const _InterestsSectionLabel({required this.count, required this.max});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '관심사',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.4)),
          ),
          child: Text(
            '$count / $max',
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? gold.withOpacity(0.16)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? gold.withOpacity(0.6)
                : Colors.white.withOpacity(0.12),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? gold : Colors.white.withOpacity(0.7)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withOpacity(0.85),
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD700);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? gold.withOpacity(0.16)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? gold.withOpacity(0.6)
                : Colors.white.withOpacity(0.12),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? gold : Colors.white.withOpacity(0.88),
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

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

class _InterestGridTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _InterestGridTile({
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
                child:
                    Icon(Icons.check_circle_rounded, color: gold, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddInterestTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddInterestTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.2),
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

class _DataUseHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 14, color: Colors.white.withOpacity(0.55)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '여기서 입력한 정보는 AI 통화 시 더 자연스러운 대화를 만드는 데에만 사용돼요. '
              '실제 이름·정확한 나이·연락처 같은 식별정보는 AI에 전달되지 않아요.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
