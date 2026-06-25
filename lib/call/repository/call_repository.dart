import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../call/models/conversation/call.dart';
import '../../call/models/conversation/message.dart';
import '../../core/crypto/diary_crypto.dart';
import '../../core/crypto/encrypted_field.dart';

/// Firestore 의 통화 기록 컬렉션 접근.
///
/// 정책: 실패 시 print + 빈 값 반환 같은 silent swallow 를 하지 않는다.
/// 호출자가 try/catch 로 처리하고 사용자에게 적절히 surface 하도록 한다.
///
/// 본문 보호: 각 메시지의 `content` 필드는 일기와 동일하게 KMS envelope 으로
/// 암호화한다. 한 통화 doc 안의 모든 메시지는 같은 DEK 를 공유 (round-trip 1 회).
class CallRepository {
  final FirebaseFirestore firestore;
  final DiaryCrypto crypto;

  CallRepository({
    required this.firestore,
    DiaryCrypto? crypto,
  }) : crypto = crypto ?? DiaryCrypto.instance;

  // ── 암호화 변환 ──

  bool _docIsEncrypted(Map<String, dynamic> raw) {
    return raw['wrappedDek'] is String && (raw['messages'] is List);
  }

  Future<Map<String, dynamic>> _encryptCall(Call call) async {
    final dek = await crypto.createDocDek();
    final wrappedDek = await crypto.wrapDek(dek);

    final encryptedMessages = await Future.wait(call.messages.map((m) async {
      final ef = await crypto.encrypt(m.content, dek);
      return {
        'role': m.role,
        'content': ef.toJson(),
      };
    }));

    return {
      'callId': call.callId,
      'timestamp': call.timestamp.toIso8601String(),
      'duration': call.duration.inSeconds,
      'wrappedDek': wrappedDek,
      'encVersion': 1,
      'messages': encryptedMessages,
    };
  }

  Future<Call> _decryptCall(Map<String, dynamic> raw) async {
    if (!_docIsEncrypted(raw)) {
      return Call.fromJson(raw);
    }
    SecretKey? dek;
    try {
      dek = await crypto.unwrapDek(raw['wrappedDek'] as String);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CallRepository] unwrap 실패 id=${raw['callId']}: $e');
      }
    }

    final rawMessages = (raw['messages'] as List?) ?? const [];
    final messages = <Message>[];
    for (final m in rawMessages) {
      final map = Map<String, dynamic>.from(m as Map);
      final contentRaw = map['content'];
      if (EncryptedField.isEncryptedJson(contentRaw) && dek != null) {
        try {
          final ef = EncryptedField.fromJson(
              Map<String, dynamic>.from(contentRaw as Map));
          final plain = await crypto.decrypt(ef, dek);
          messages.add(Message(role: map['role'] as String, content: plain));
        } catch (e) {
          if (kDebugMode) debugPrint('[CallRepository] msg decrypt 실패: $e');
          messages.add(
              Message(role: map['role'] as String, content: '(복호화 실패)'));
        }
      } else if (contentRaw is String) {
        messages.add(Message(role: map['role'] as String, content: contentRaw));
      } else {
        messages.add(
            Message(role: map['role'] as String, content: '(복호화 실패)'));
      }
    }

    return Call(
      callId: raw['callId'] as String,
      timestamp: DateTime.parse(raw['timestamp'] as String),
      duration: Duration(seconds: raw['duration'] as int),
      messages: messages,
    );
  }

  // ── 공개 API ──

  Future<List<Call>> fetchCalls(String userId, {int limit = 50}) async {
    final snapshot = await firestore
        .collection('users/$userId/call')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    final docs = snapshot.docs.map((d) => d.data()).toList();
    return Future.wait(docs.map(_decryptCall));
  }

  Future<Call?> getCallById(String userId, String callId) async {
    final doc = await firestore.doc('users/$userId/call/$callId').get();
    if (!doc.exists) return null;
    return _decryptCall(doc.data()!);
  }

  Future<void> saveCall(String userId, Call call) async {
    final encrypted = await _encryptCall(call);
    await firestore.doc('users/$userId/call/${call.callId}').set(encrypted);
  }

  Future<void> deleteCall(String userId, String callId) async {
    await firestore.doc('users/$userId/call/$callId').delete();
  }
}
