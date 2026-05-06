import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final _remoteConfig = FirebaseRemoteConfig.instance;

  /// 첫 fetch 가 성공적으로 활성화됐는지 여부.
  /// false 인 경우 openAIApiKey 가 빈 문자열일 가능성이 매우 높음.
  bool _activated = false;
  bool get isActivated => _activated;

  Future<void> initialize() async {
    // ✅ 기본 minimumFetchInterval 은 12시간이라 첫 설치 시점에 캐시가 없으면
    //    다음 fetch까지 12시간 기다려야 함. 디버그 빌드는 0초로, 릴리즈도 5분으로
    //    줄여서 키 회전이나 첫 fetch 실패 후 재시도가 제때 반영되게 한다.
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 30),
        minimumFetchInterval:
            kReleaseMode ? const Duration(minutes: 5) : Duration.zero,
      ));
    } catch (e) {
      // 설정 실패는 치명적이지 않음 — 기본값으로 진행
      debugPrint('[RemoteConfig] setConfigSettings 실패: $e');
    }

    await _remoteConfig.setDefaults({'openai_api_key': ''});

    // ✅ fetchAndActivate 는 실패해도 예외를 던지지 않고 false 만 반환할 수 있음.
    //    릴리즈 빌드에서 첫 fetch 가 타임아웃되면 키가 빈 문자열로 남아
    //    이후 OpenAI 호출이 401로 silent 실패하므로 결과를 명시적으로 로그해 둠.
    //    debugPrint() 는 debugPrint 와 달리 릴리즈 모드에서도 logcat 에 출력됨.
    try {
      _activated = await _remoteConfig.fetchAndActivate();
      final keyLen = _remoteConfig.getString('openai_api_key').length;
      debugPrint('[RemoteConfig] fetchAndActivate=$_activated, '
          'openai_api_key.length=$keyLen');
    } catch (e) {
      debugPrint('[RemoteConfig] ❌ fetchAndActivate 예외: $e');
      _activated = false;
    }

    // ✅ 첫 fetch 가 실패했으면 한 번 더 시도 (네트워크가 늦게 붙는 경우 대비).
    if (!_activated || openAIApiKey.isEmpty) {
      try {
        await Future.delayed(const Duration(milliseconds: 800));
        _activated = await _remoteConfig.fetchAndActivate();
        final keyLen = _remoteConfig.getString('openai_api_key').length;
        debugPrint('[RemoteConfig] retry fetchAndActivate=$_activated, '
            'openai_api_key.length=$keyLen');
      } catch (e) {
        debugPrint('[RemoteConfig] ❌ retry 예외: $e');
      }
    }
  }

  String get openAIApiKey => _remoteConfig.getString('openai_api_key');
}
