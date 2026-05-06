import 'package:intl/intl.dart';

/// 한국어 상대시간 ("2시간 전" 등). 일주일 넘으면 "M월 d일" 로 떨어진다.
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(time);

  if (diff.isNegative) return '방금 전';
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return DateFormat('M월 d일', 'ko_KR').format(time);
}
