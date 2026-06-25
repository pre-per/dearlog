import 'dart:ui';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/providers.dart';
import '../../core/base_scaffold.dart';
import '../../user/models/user_stats.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../../user/providers/user_stats_providers.dart';
import '../providers/anonymous_default_provider.dart';
import '../providers/community_safety_providers.dart';

/// 백필 권한이 있는 admin uid 화이트리스트 — Cloud Function 의 admin.uids 와 동일.
/// 이 화면 하단의 백필 버튼은 이 목록의 사용자에게만 노출된다.
const _adminUids = <String>{
  'RFpGClUpwjbuioRzbn6w964zhOC3',
};

/// 커뮤니티 관련 사용자 설정 화면.
///
/// - 익명 기본값: 댓글 입력바·게시글 공유 화면에서 익명 토글의 초기값.
/// - 익명일 때 랭크 노출: 익명으로 작성해도 내 랭크 배지/스트릭 글로우는 보여줄지.
///   끄면 완전 익명, 켜면 자랑은 하고 싶지만 본문 식별은 가리고 싶은 사용자용.
class CommunitySettingsScreen extends ConsumerWidget {
  const CommunitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anonymous = ref.watch(anonymousDefaultProvider);
    final user = ref.watch(userProvider).valueOrNull;
    final showRankWhenAnon = user?.preferences.showRankWhenAnonymous ?? false;

    return BaseScaffold(
      appBar: AppBar(
        title: const Text('커뮤니티 설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const SizedBox(height: 8),
          _AnonymousDefaultCard(
            value: anonymous,
            onChanged: (v) =>
                ref.read(anonymousDefaultProvider.notifier).setAnonymous(v),
          ),
          const SizedBox(height: 12),
          _ShowRankWhenAnonymousCard(
            value: showRankWhenAnon,
            enabled: user != null,
            onChanged: (v) async {
              if (user == null) return;
              final newPrefs =
                  user.preferences.copyWith(showRankWhenAnonymous: v);
              await ref
                  .read(userRepositoryProvider)
                  .savePreferences(user.id, newPrefs);
              ref.invalidate(userProvider);
            },
          ),
          const SizedBox(height: 12),
          const _BlockedUsersCard(),
          if (user != null && _adminUids.contains(user.id)) ...[
            const SizedBox(height: 28),
            const _AdminBackfillCard(),
            const SizedBox(height: 12),
            const _DebugStatsCard(),
          ],
        ],
      ),
    );
  }
}

/// 차단한 사용자 목록 + 해제. 게시물/댓글의 [차단] 으로 추가된 사용자들이
/// 여기 모이고, 해제하면 그 사용자의 콘텐츠가 즉시 다시 보인다.
class _BlockedUsersCard extends ConsumerWidget {
  const _BlockedUsersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedUsersProvider);
    final myUid = ref.watch(userIdProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '차단한 사용자',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '차단한 사용자의 게시물과 댓글은 나에게 보이지 않아요.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              blockedAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, __) => Text(
                  '차단 목록을 불러오지 못했어요',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                data: (blocked) {
                  if (blocked.isEmpty) {
                    return Text(
                      '차단한 사용자가 없어요',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 13,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final entry in blocked.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: myUid == null
                                    ? null
                                    : () async {
                                        try {
                                          await CommunitySafetyActions
                                              .unblockUser(
                                            myUid: myUid,
                                            targetUid: entry.key,
                                          );
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content:
                                                      Text('해제 실패: $e')),
                                            );
                                          }
                                        }
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                        color:
                                            Colors.white.withOpacity(0.18)),
                                  ),
                                  child: const Text(
                                    '차단 해제',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// admin 전용 — Cloud Function `backfillAllUserStats` 호출 버튼.
/// 기존 사용자들의 일기 데이터로 user_stats 컬렉션을 1회 채운다.
class _AdminBackfillCard extends StatefulWidget {
  const _AdminBackfillCard();

  @override
  State<_AdminBackfillCard> createState() => _AdminBackfillCardState();
}

class _AdminBackfillCardState extends State<_AdminBackfillCard> {
  bool _running = false;
  String? _result;

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _result = null;
    });
    try {
      final res = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('backfillAllUserStats')
          .call();
      final data = res.data as Map<dynamic, dynamic>? ?? const {};
      setState(() {
        _result =
            '완료: totalUsers=${data['totalUsers']}, processed=${data['processed']}, failed=${data['failed']}';
      });
    } catch (e) {
      setState(() => _result = '실패: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🛠 Admin · 랭킹 백필',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '모든 사용자의 일기 컬렉션을 스캔해서 user_stats 를 1회 재계산해요. 멱등 동작이라 여러 번 눌러도 안전.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _running ? null : _run,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _running
                        ? Colors.white.withOpacity(0.08)
                        : const Color(0xFFFFD700).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    _running ? '실행 중…' : '백필 실행',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (_result != null) ...[
                const SizedBox(height: 10),
                Text(
                  _result!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowRankWhenAnonymousCard extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _ShowRankWhenAnonymousCard({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '익명일 때도 랭크 보이기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '익명으로 글이나 댓글을 써도 내 등급 배지와 연속 기록 글로우는 보여요.\n끄면 완전히 익명으로 노출돼요.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CupertinoSwitch(
                value: value,
                activeColor: const Color(0xFFFFD700),
                onChanged: enabled ? onChanged : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnonymousDefaultCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _AnonymousDefaultCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '익명으로 작성',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '댓글과 게시글을 쓸 때 기본적으로 익명으로 시작해요.\n작성 화면에서 그때그때 끌 수도 있어요.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CupertinoSwitch(
                value: value,
                activeColor: const Color(0xFFFFD700),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// admin 전용 — user_stats 의 diaryCount / currentStreak 를 +/- 로 즉시 조정.
/// 실제 일기를 쓰지 않고 랭크 배지·티어·축하 연출·스트릭 글로우를 빠르게 검증.
///
/// 적용 후 사용자가 새 일기를 작성하면 onWrite 트리거가 다시 실제 값으로
/// 덮어쓴다 — 디버그 값은 일시적.
class _DebugStatsCard extends ConsumerWidget {
  const _DebugStatsCard();

  Future<void> _set(WidgetRef ref, int diaryCount, int currentStreak) async {
    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('debugSetUserStats')
          .call({
        'diaryCount': diaryCount,
        'currentStreak': currentStreak,
      });
    } catch (e) {
      // 디버그용이라 사용자에게 굳이 알릴 필요 없이 콘솔만.
      // ignore: avoid_print
      print('[debugSetUserStats] failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats =
        ref.watch(myUserStatsProvider).maybeWhen(data: (s) => s, orElse: () => null) ??
            UserStats.empty();
    final count = stats.diaryCount;
    final streak = stats.currentStreak;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B9D).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF6B9D).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🧪 Debug · 등급/스트릭 조작',
                style: TextStyle(
                  color: Color(0xFFFF6B9D),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '실제 일기 없이 랭크와 글로우를 검증할 때 사용. 새 일기 쓰면 자동으로 실제 값으로 돌아와요.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),

              // 일기 일수 행
              _RowAdjuster(
                label: '일기 일수',
                value: count,
                onChange: (delta) => _set(ref, count + delta, streak),
              ),
              const SizedBox(height: 10),

              // 스트릭 일수 행
              _RowAdjuster(
                label: '연속 일수',
                value: streak,
                onChange: (delta) => _set(ref, count, streak + delta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowAdjuster extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChange;

  const _RowAdjuster({
    required this.label,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        _StepBtn(label: '−10', onTap: () => onChange(-10)),
        const SizedBox(width: 6),
        _StepBtn(label: '−1', onTap: () => onChange(-1)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _StepBtn(label: '+1', onTap: () => onChange(1)),
        const SizedBox(width: 6),
        _StepBtn(label: '+10', onTap: () => onChange(10)),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StepBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B9D).withOpacity(0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFF6B9D).withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFF6B9D),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

