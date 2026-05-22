import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'encrypted_field.dart';

/// 클라이언트 측 AES-256-GCM 암복호화 + Cloud Functions(KMS) 를 통한 DEK
/// wrap/unwrap 헬퍼.
///
/// 사용 패턴:
/// - 저장: [createDocDek] 으로 새 DEK 생성 → [encrypt] 로 각 필드 암호화 →
///   [wrapDek] 으로 KMS wrap → Firestore 에 `wrappedDek` + 각 필드의
///   [EncryptedField] 저장.
/// - 조회: Firestore 에서 `wrappedDek` 가져옴 → [unwrapDek] 으로 KMS unwrap →
///   [decrypt] 로 필드별 복호화.
///
/// 다중 doc 을 한꺼번에 읽을 땐 [unwrapDeks] 로 KMS 호출을 한 번에 묶을 수 있다.
///
/// 평문 DEK 는 GC 가 비교적 빨리 회수하도록 작업 단위로 짧게만 들고 있어야 한다.
/// 절대로 SharedPreferences/Firestore/디스크에 저장하지 말 것.
class DiaryCrypto {
  DiaryCrypto._();
  static final DiaryCrypto instance = DiaryCrypto._();

  static const int _kDekByteLen = 32; // AES-256
  static const int _kIvByteLen = 12; // GCM 표준 nonce

  // cryptography 패키지의 권장 패턴: 매 호출 새 인스턴스를 만들지 말고 재사용.
  // 내부적으로 안전하게 재사용 가능 (state-less).
  final AesGcm _aes = AesGcm.with256bits();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// 새로운 doc 용 DEK 1개를 만든다 (32 random bytes).
  Future<SecretKey> createDocDek() async {
    return _aes.newSecretKey();
  }

  /// 평문 [text] 를 [dek] 로 AES-256-GCM 암호화. 매번 새 IV 사용.
  Future<EncryptedField> encrypt(String text, SecretKey dek) async {
    final nonce = _aes.newNonce(); // 12 bytes random
    final secretBox = await _aes.encrypt(
      utf8.encode(text),
      secretKey: dek,
      nonce: nonce,
    );
    // SecretBox 는 cipherText + mac 을 분리해서 갖고 있다.
    // 우리 포맷은 `ct = cipherText + mac`, `iv = nonce`.
    final ctBytes = Uint8List(secretBox.cipherText.length + secretBox.mac.bytes.length)
      ..setRange(0, secretBox.cipherText.length, secretBox.cipherText)
      ..setRange(
        secretBox.cipherText.length,
        secretBox.cipherText.length + secretBox.mac.bytes.length,
        secretBox.mac.bytes,
      );
    return EncryptedField(
      iv: base64.encode(nonce),
      ct: base64.encode(ctBytes),
    );
  }

  /// [EncryptedField] 를 [dek] 로 복호화해 원래 문자열을 돌려준다.
  /// 위조/손상되었으면 [SecretBoxAuthenticationError] 가 던져진다.
  Future<String> decrypt(EncryptedField field, SecretKey dek) async {
    final iv = base64.decode(field.iv);
    final ctAndMac = base64.decode(field.ct);
    if (ctAndMac.length < 16) {
      throw const FormatException('암호문이 너무 짧아요 (MAC 누락 의심)');
    }
    final macLen = 16; // GCM tag size
    final cipherText = ctAndMac.sublist(0, ctAndMac.length - macLen);
    final macBytes = ctAndMac.sublist(ctAndMac.length - macLen);
    final secretBox = SecretBox(
      cipherText,
      nonce: iv,
      mac: Mac(macBytes),
    );
    final clear = await _aes.decrypt(secretBox, secretKey: dek);
    return utf8.decode(clear);
  }

  // ── KMS wrap/unwrap (Cloud Functions) ──

  /// 새로 만든 [dek] 를 KMS 마스터키로 wrap 해 base64 wrappedDek 을 돌려준다.
  /// 저장 시 doc 에 함께 기록한다.
  Future<String> wrapDek(SecretKey dek) async {
    final bytes = await dek.extractBytes();
    if (bytes.length != _kDekByteLen) {
      throw StateError(
          'DEK 길이가 잘못됐어요 (${bytes.length} bytes — 32 bytes 필요)');
    }
    final callable = _functions.httpsCallable('wrapDek');
    final result = await callable.call({'dek': base64.encode(bytes)});
    final wrapped = result.data?['wrappedDek'] as String?;
    if (wrapped == null || wrapped.isEmpty) {
      throw StateError('wrapDek 응답에 wrappedDek 가 없어요');
    }
    return wrapped;
  }

  /// 저장된 [wrappedDek] 를 KMS 로 unwrap 해 [SecretKey] 로 돌려준다.
  /// 다른 사용자의 wrappedDek 이면 함수단에서 AAD mismatch 로 거절된다.
  Future<SecretKey> unwrapDek(String wrappedDek) async {
    final callable = _functions.httpsCallable('unwrapDek');
    final result = await callable.call({'wrappedDek': wrappedDek});
    final dekB64 = result.data?['dek'] as String?;
    if (dekB64 == null || dekB64.isEmpty) {
      throw StateError('unwrapDek 응답에 dek 가 없어요');
    }
    final bytes = base64.decode(dekB64);
    return SecretKey(bytes);
  }

  /// 일괄 unwrap. 다이어리 목록 화면처럼 한 번에 N 개 doc 을 복호화해야 할 때 사용.
  /// 일부 항목이 실패하면 해당 인덱스에 null 이 들어간다 (caller 가 fallback 처리).
  Future<List<SecretKey?>> unwrapDeks(List<String> wrappedDeks) async {
    if (wrappedDeks.isEmpty) return const [];
    final callable = _functions.httpsCallable('unwrapDeks');
    final result =
        await callable.call({'wrappedDeks': wrappedDeks});
    final raw = (result.data?['results'] as List?) ?? const [];
    return raw.map<SecretKey?>((entry) {
      if (entry is! Map) return null;
      final dekB64 = entry['dek'] as String?;
      if (dekB64 == null || dekB64.isEmpty) return null;
      try {
        return SecretKey(base64.decode(dekB64));
      } catch (e) {
        if (kDebugMode) debugPrint('[DiaryCrypto] dek decode 실패: $e');
        return null;
      }
    }).toList();
  }

  // ── 편의 메서드 ──

  /// 평문 한 줄을 새 DEK 로 암호화하고, DEK 도 KMS 로 wrap 해서
  /// `(wrappedDek, encryptedField)` 한 쌍을 돌려준다.
  /// doc 안에 단 하나의 필드만 암호화하는 단순한 케이스용.
  Future<({String wrappedDek, EncryptedField field})> sealOne(
      String plaintext) async {
    final dek = await createDocDek();
    final field = await encrypt(plaintext, dek);
    final wrapped = await wrapDek(dek);
    return (wrappedDek: wrapped, field: field);
  }

  /// `wrappedDek` + 단일 [EncryptedField] 를 받아 원문을 돌려주는 단순 케이스.
  Future<String> openOne(String wrappedDek, EncryptedField field) async {
    final dek = await unwrapDek(wrappedDek);
    return decrypt(field, dek);
  }
}
