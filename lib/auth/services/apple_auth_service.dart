import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// 애플 로그인 (Sign in with Apple).
///
/// App Store 심사 가이드라인 4.8 — 구글 같은 서드파티 로그인을 제공하는 앱은
/// 애플 로그인도 함께 제공해야 한다. iOS 에서만 노출한다 (안드로이드는 별도
/// 웹 인증(Service ID) 설정이 필요해서 지원하지 않음).
class AppleAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// 애플 로그인 실행. 사용자가 시트를 닫으면 null (구글의 계정 선택 취소와 동일).
  Future<UserCredential?> signInWithApple() async {
    try {
      // 1. 네이티브 시트로 애플 자격 증명 획득.
      //    nonce: 발급받은 idToken 이 이 세션의 것임을 Firebase 가 검증할 수 있게
      //    하는 재전송 공격 방지 장치 — 원문은 Firebase 에, 해시는 애플에 전달.
      final rawNonce = _generateNonce();
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
        nonce: _sha256ofString(rawNonce),
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        debugPrint('Apple 로그인 실패: identityToken 없음');
        return null;
      }

      // 2. Firebase Auth용 Credential 생성
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
      );

      // 3. Firebase 로그인 처리
      return await _firebaseAuth.signInWithCredential(oauthCredential);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      debugPrint('Apple 로그인 실패: $e');
      return null;
    } on FirebaseAuthException {
      // account-exists-with-different-credential 등은 화면에서 안내 메시지 분기
      rethrow;
    } catch (e) {
      debugPrint('Apple 로그인 실패: $e');
      return null;
    }
  }

  /// 회원탈퇴 직전 재인증 + 애플 토큰 철회.
  ///
  /// App Store 심사 가이드라인 5.1.1(v) — 애플 로그인 계정을 삭제할 때는 앱과
  /// 애플 계정의 연결(토큰)도 함께 revoke 해야 한다. 철회에는 방금 발급된
  /// 미사용 authorizationCode 가 필요해서 탈퇴 시점에 재인증을 같이 한다.
  ///
  /// 재인증 취소/실패 시 throw — 호출부에서 탈퇴를 중단해야 한다.
  /// 토큰 철회 자체의 실패는 탈퇴를 막지 않는다 (best-effort).
  Future<void> reauthenticateForWithdrawal() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No user');

    final rawNonce = _generateNonce();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
      nonce: _sha256ofString(rawNonce),
    );

    final idToken = appleCredential.identityToken;
    if (idToken == null) throw Exception('Apple identityToken 없음');

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
    );
    await user.reauthenticateWithCredential(oauthCredential);

    try {
      await _firebaseAuth.revokeTokenWithAuthorizationCode(
        appleCredential.authorizationCode,
      );
    } catch (e) {
      debugPrint('[withdraw] Apple 토큰 철회 실패 (탈퇴는 계속 진행): $e');
    }
  }

  /// 로그아웃 처리 — 애플은 구글과 달리 따로 끊을 SDK 세션이 없다.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// 현재 로그인된 사용자 반환
  User? get currentUser => _firebaseAuth.currentUser;

  /// 암호학적으로 안전한 랜덤 nonce 생성
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}
