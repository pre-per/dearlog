// lib/app/di/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../../ai/services/openai_service.dart';
import '../../user/repository/user_repository.dart';
import '../../diary/repository/diary_repository.dart';
import '../../call/repository/call_repository.dart';

/// ===== Firebase singletons =====
final firebaseAuthProvider   = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
final firestoreProvider      = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

/// ===== External services =====
final openAIServiceProvider  = Provider<OpenAIService>((ref) {
  // 필요하면 RemoteConfig/환경 분기 사용 가능
  return OpenAIService();
});

/// ===== Repositories =====
final userRepositoryProvider  = Provider<UserRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return UserRepository(firestore: db);
});

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return DiaryRepository(firestore: db);
});

final callRepositoryProvider  = Provider<CallRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return CallRepository(firestore: db);
});