import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dearlog/call/models/conversation/message.dart';

class ConversationBackupService {
  static const _messagesKey = 'backup_messages';
  static const _timestampKey = 'backup_timestamp';

  /// 통화 메시지를 로컬에 백업. 통화 중 강제 종료 등으로 일기 생성이 끊기면
  /// 다음 진입 시 [hasBackup] 으로 감지해 사용자에게 복구를 제안한다.
  static Future<void> save(List<Message> messages) async {
    final filtered = messages.where((m) => m.content != '__loading__').toList();
    if (filtered.length <= 1) return; // 첫 인삿말만 있으면 저장 안 함

    final prefs = await SharedPreferences.getInstance();
    final json = filtered.map((m) => {'role': m.role, 'content': m.content}).toList();
    await prefs.setString(_messagesKey, jsonEncode(json));
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
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
  }
}
