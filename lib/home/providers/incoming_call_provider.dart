import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 통화 배너의 글로벌 표시 상태.
///
/// 한 번에 한 개만 표시되도록 보장하고, 어느 탭에서든 통화 버튼이
/// 같은 상태를 공유한다. 배너가 떠 있는 동안 모든 통화 버튼은 비활성화.
final incomingCallVisibleProvider = StateProvider<bool>((ref) => false);
