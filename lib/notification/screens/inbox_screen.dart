import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../community/utils/relative_time.dart';
import '../../core/base_scaffold.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../models/notification_record.dart';
import '../providers/inbox_providers.dart';
import '../utils/notification_navigator.dart';

/// 알림 보관함 — 사용자가 받은 알림 영구 기록.
///
/// 진입 시:
/// - 미읽음 모두 읽음 처리
/// - 30일 이상 된 항목 자동 정리 (Firestore 비용 절감)
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onEntered());
  }

  Future<void> _onEntered() async {
    final uid = ref.read(userIdProvider);
    if (uid == null) return;
    final repo = ref.read(inboxRepositoryProvider);
    // 두 작업 병렬 — 서로 의존 없음. 실패해도 화면은 정상 동작.
    repo.markAllRead(uid).catchError((_) {});
    repo.deleteOlderThan(uid, const Duration(days: 30)).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(inboxStreamProvider);

    return BaseScaffold(
      appBar: AppBar(
        title: const Text(
          '알림',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'GowunBatang',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: inboxAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _MessageView(
          title: '알림을 불러오지 못했어요',
          subtitle: '$e',
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _MessageView(
              title: '받은 알림이 없어요',
              subtitle: '커뮤니티 게시물에 댓글이 달리면 여기에 모아둘게요',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _NotificationCard(record: items[i]),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationRecord record;
  const _NotificationCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (record.payload.isEmpty) return;
        // main.dart 의 _handlePendingNotificationPayload 가 받아서 라우팅한다.
        NotificationCenter.post(record.payload);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!record.read)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700),
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    record.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatRelativeTime(record.createdAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontFamily: 'GowunBatang',
                  ),
                ),
              ],
            ),
            if (record.body.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding:
                    EdgeInsets.only(left: record.read ? 0 : 14),
                child: Text(
                  '"${record.body}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 13,
                    height: 1.5,
                    fontFamily: 'GowunBatang',
                  ),
                ),
              ),
            ],
            if (record.postTitle != null &&
                record.postTitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding:
                    EdgeInsets.only(left: record.read ? 0 : 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: Text(
                    record.postTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final String title;
  final String subtitle;
  const _MessageView({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'GowunBatang',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontFamily: 'GowunBatang',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
