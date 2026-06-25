import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPrefsKey = 'community_anonymous_default';

/// 사용자의 익명 작성 선호도를 SharedPreferences 에 영속화.
///
/// 댓글/대댓글 입력바, 게시글 공유 화면, 설정 화면이 모두 같은 값을 공유한다 —
/// 즉 어디서 토글하든 다음 작성 시 같은 기본값으로 시작한다. 기기 단위 저장.
class AnonymousDefaultNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_kPrefsKey);
      if (saved != null) state = saved;
    } catch (_) {/* 실패 시 default(false) 유지 */}
  }

  Future<void> setAnonymous(bool value) async {
    if (state == value) return;
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefsKey, value);
    } catch (_) {/* 영속화 실패해도 메모리 상태는 그대로 */}
  }

  Future<void> toggle() => setAnonymous(!state);
}

final anonymousDefaultProvider =
    NotifierProvider<AnonymousDefaultNotifier, bool>(AnonymousDefaultNotifier.new);
