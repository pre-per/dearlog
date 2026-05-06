import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dearlog/call/models/conversation/message.dart';

class ConversationBackupService {
  static const _messagesKey = 'backup_messages';
  static const _timestampKey = 'backup_timestamp';
  static const _illustrationKey = 'backup_with_illustration';

  /// 통화 메시지 + (선택) 사용자가 통화 시작 시 켰던 illustration 토글 값을 저장.
  /// 복구 시에도 같은 토글로 일기 생성하도록 [getWithIllustration] 으로 읽어서 사용.
  static Future<void> save(
    List<Message> messages, {
    bool withIllustration = true,
  }) async {
    final filtered = messages.where((m) => m.content != '__loading__').toList();
    if (filtered.length <= 1) return; // 첫 인삿말만 있으면 저장 안 함

    final prefs = await SharedPreferences.getInstance();
    final json = filtered.map((m) => {'role': m.role, 'content': m.content}).toList();
    await prefs.setString(_messagesKey, jsonEncode(json));
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setBool(_illustrationKey, withIllustration);
  }

  static Future<List<Message>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_messagesKey);
    if (jsonStr == null) return null;

    final list = jsonDecode(jsonStr) as List;
    return list
        .map((m) => Message(role: m['role'] as String, content: m['content'] as String))
        .toList();
  }

  /// 백업 시 저장된 illustration 토글 값. 없으면 기본 true (이전 버전 호환).
  static Future<bool> getWithIllustration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_illustrationKey) ?? true;
  }

  static Future<DateTime?> getTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_timestampKey);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  static Future<bool> hasBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_messagesKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_messagesKey);
    await prefs.remove(_timestampKey);
    await prefs.remove(_illustrationKey);
  }
}
