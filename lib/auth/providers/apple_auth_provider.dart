import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/apple_auth_service.dart';

class AppleAuthNotifier extends Notifier<User?> {
  final _authService = AppleAuthService();

  @override
  User? build() {
    return _authService.currentUser;
  }

  bool get isLoggedIn => state != null;

  Future<void> login() async {
    final credential = await _authService.signInWithApple();
    state = credential?.user;
  }

  Future<void> logout() async {
    await _authService.signOut();
    state = null;
  }
}

/// Provider 선언
final appleAuthProvider = NotifierProvider<AppleAuthNotifier, User?>(
  () => AppleAuthNotifier(),
);
