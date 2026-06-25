import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/providers/user_fetch_providers.dart';
import '../models/my_planet.dart';
import '../providers/planet_providers.dart';

/// 행성 공개 설정 바텀시트. 1차에서는 값 저장만 — 커뮤니티 방문 연동은 다음 단계.
Future<void> showPlanetVisibilitySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PlanetVisibilitySheet(),
  );
}

class _PlanetVisibilitySheet extends ConsumerWidget {
  const _PlanetVisibilitySheet();

  void _select(BuildContext context, WidgetRef ref, PlanetVisibility value) {
    final uid = ref.read(userIdProvider);
    if (uid == null || uid.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final repo = ref.read(planetRepositoryProvider);
    final updated = ref.read(myPlanetProvider).copyWith(visibility: value);
    Navigator.of(context).pop();
    // 화장성 저장 — 로컬 캐시에 즉시 반영되어 화면이 바로 갱신된다. 네트워크
    // 미연결 시 Firestore 가 큐잉/재시도하므로 await 하지 않는다(오프라인 hang 방지).
    unawaited(repo.saveMyPlanet(uid, updated));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(myPlanetProvider).visibility;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: BoxDecoration(
            color: const Color(0xFF131B28).withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  '행성 공개 설정',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '다른 사람에게 내 행성을 어떻게 보여줄지 정해요.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 16),
                for (final v in PlanetVisibility.values)
                  _VisibilityOption(
                    visibility: v,
                    selected: v == current,
                    onTap: () => _select(context, ref, v),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  final PlanetVisibility visibility;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityOption({
    required this.visibility,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:
              selected
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected
                    ? const Color(0xFFFFD27A).withOpacity(0.5)
                    : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visibility.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    visibility.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color:
                  selected
                      ? const Color(0xFFFFD27A)
                      : Colors.white.withOpacity(0.35),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
