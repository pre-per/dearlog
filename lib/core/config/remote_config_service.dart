import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    await _remoteConfig.setDefaults({'openai_api_key': ''});
    await _remoteConfig.fetchAndActivate();
  }

  String get openAIApiKey => _remoteConfig.getString('openai_api_key');
}
