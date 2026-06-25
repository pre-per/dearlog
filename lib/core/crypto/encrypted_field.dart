/// Firestore 에 저장되는 한 필드의 AES-256-GCM 암호문 + IV 묶음.
///
/// 같은 doc 안의 다른 암호문들은 같은 [DiaryCrypto.docDek] 를 공유하지만 각각
/// 다른 IV 를 가진다. wrappedDek 은 doc 의 메타 필드(`wrappedDek`)에 별도로 저장.
class EncryptedField {
  /// AES-256-GCM 의 12-byte nonce, base64.
  final String iv;

  /// 암호문 + 16-byte 인증 태그. base64.
  ///
  /// `cryptography` 패키지는 [SecretBox.concatenation] 으로 만들면
  /// `iv + cipher + mac` 한 덩어리를 주지만, 우리는 IV 를 별도 필드로
  /// 저장하므로 여기엔 `cipher + mac` 만 들어간다.
  final String ct;

  const EncryptedField({required this.iv, required this.ct});

  Map<String, dynamic> toJson() => {'iv': iv, 'ct': ct};

  factory EncryptedField.fromJson(Map<String, dynamic> json) {
    return EncryptedField(
      iv: (json['iv'] as String?) ?? '',
      ct: (json['ct'] as String?) ?? '',
    );
  }

  /// Firestore 에 저장된 raw 값이 우리 EncryptedField 포맷인지 — `{iv, ct}` 객체인지
  /// 아니면 legacy 평문 문자열인지 판별. legacy 호환에 쓴다.
  static bool isEncryptedJson(Object? raw) {
    if (raw is! Map) return false;
    return raw['iv'] is String && raw['ct'] is String;
  }
}
