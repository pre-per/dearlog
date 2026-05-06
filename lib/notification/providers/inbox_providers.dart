import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/providers.dart';
import '../../user/providers/user_fetch_providers.dart';
import '../models/notification_record.dart';
import '../repository/notification_inbox_repository.dart';

final inboxRepositoryProvider = Provider<NotificationInboxRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return NotificationInboxRepository(firestore: db);
});

/// 알림 보관함 라이브 리스트.
final inboxStreamProvider =
    StreamProvider.autoDispose<List<NotificationRecord>>((ref) {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return const Stream.empty();
  final repo = ref.watch(inboxRepositoryProvider);
  return repo.watch(uid);
});

/// 안 읽은 알림 개수 — 홈 화면의 미읽음 배지가 watch.
final unreadInboxCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return Stream.value(0);
  final repo = ref.watch(inboxRepositoryProvider);
  return repo.watchUnreadCount(uid);
});
