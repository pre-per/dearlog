import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();


  /// 구글 로그인 실행
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. 사용자 계정 선택
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // 2. 인증 정보 획득
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Firebase Auth용 Credential 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Firebase 로그인 처리
      return await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      print('Google 로그인 실패: $e');
      return null;
    }
  }

  /// 로그아웃 처리
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  /// 현재 로그인된 사용자 반환
  User? get currentUser => _firebaseAuth.currentUser;
}
