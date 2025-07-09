import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/google_auth_service.dart';

class GoogleAuthNotifier extends Notifier<User?> {
  final _authService = GoogleAuthService();

  @override
  User? build() {
    return _authService.currentUser;
  }

  bool get isLoggedIn => state != null;

  Future<void> login() async {
    final credential = await _authService.signInWithGoogle();
    state = credential?.user;
  }

  Future<void> logout() async {
    await _authService.signOut();
    state = null;
  }
}

/// Provider 선언
final googleAuthProvider = NotifierProvider<GoogleAuthNotifier, User?>(
  () => GoogleAuthNotifier(),
);
