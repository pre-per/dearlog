import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dearlog/app.dart';
import 'package:dearlog/call/providers/voice_provider.dart';
import 'package:dearlog/community/repository/community_repository.dart';
import 'package:dearlog/community/screens/community_settings_screen.dart';
import 'package:dearlog/community/widgets/my_rank_card.dart';
import 'package:dearlog/planet/widgets/my_planet_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingMainScreen extends ConsumerWidget {
  // ConsumerWidget 이지만 const 가 아닌 인스턴스 변수로 컨트롤러를 관리하면
  // build 마다 새 컨트롤러가 만들어져 입력 중인 텍스트가 사라지는 문제를 막을 수 있다.
  // (main.dart 의 `_screens` 가 한 번만 인스턴스화하므로 lifetime 동안 한 컨트롤러만 산다)
  // 더 엄격하게는 ConsumerStatefulWidget 으로 dispose 까지 관리하는 게 정석.
  // ignore: prefer_const_constructors_in_immutables
  SettingMainScreen({super.key});

  final TextEditingController _feedbackController = TextEditingController();

  Future<void> _reauthenticateWithGoogle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user');

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await user.reauthenticateWithCredential(credential);
  }

  /// 현재 계정이 애플 로그인으로 가입한 계정인지
  bool _isAppleUser(User user) =>
      user.providerData.any((p) => p.providerId == 'apple.com');

  /// 탈퇴용 재인증 — 가입 제공자(애플/구글)에 맞는 인증 픽커를 띄운다.
  /// 애플 계정은 재인증과 함께 토큰 철회(App Store 5.1.1(v))까지 수행된다.
  Future<void> _reauthenticateForWithdraw(User user) async {
    if (_isAppleUser(user)) {
      await AppleAuthService().reauthenticateForWithdrawal();
    } else {
      await _reauthenticateWithGoogle();
    }
  }

  /// Firestore 서브컬렉션(문서들) 전부 삭제
  Future<void> _deleteSubcollection({
    required String uid,
    required String subcollectionName,
  }) async {
    final colRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(subcollectionName);

    while (true) {
      final snap = await colRef.limit(200).get();
      if (snap.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Storage 폴더(내부 모든 파일/하위폴더) 전부 삭제
  Future<void> _deleteStorageFolder(String folderPath) async {
    final ref = FirebaseStorage.instance.ref(folderPath);

    // 폴더 안을 나눠서 받아옴(파일 + 하위폴더)
    final listResult = await ref.listAll();

    // 파일 삭제
    for (final item in listResult.items) {
      await item.delete();
    }

    // 하위 폴더 재귀 삭제
    for (final prefix in listResult.prefixes) {
      await _deleteStorageFolder(prefix.fullPath);
    }
  }

  /// 본인 uid 로 묶인 외부 컬렉션 (community_posts, community_reports, feedbacks) 정리.
  /// 회원탈퇴 시 호출 — 탈퇴 후에도 닉네임/신고/피드백 기록이 남지 않게.
  Future<void> _deleteUserOwnedExternalDocs(String uid) async {
    // 1) 본인이 게시한 공개 게시물 모두 내림 (댓글/좋아요/스토리지 이미지까지 정리)
    try {
      final myPosts = await FirebaseFirestore.instance
          .collection('community_posts')
          .where('authorUid', isEqualTo: uid)
          .get();
      final repo = CommunityRepository();
      for (final doc in myPosts.docs) {
        try {
          await repo.takeDownPost(doc.id);
        } catch (_) {/* 부분 실패 허용 — 다음 문서로 진행 */}
      }
    } catch (e) {
      debugPrint('[withdraw] community_posts cleanup failed: $e');
    }

    // 2) 본인 신고 기록 삭제 (firestore.rules 에서 self-delete 허용 필요)
    try {
      while (true) {
        final snap = await FirebaseFirestore.instance
            .collection('community_reports')
            .where('reporterUid', isEqualTo: uid)
            .limit(200)
            .get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[withdraw] community_reports cleanup failed: $e');
    }

    // 3) 본인이 보낸 피드백 삭제
    try {
      while (true) {
        final snap = await FirebaseFirestore.instance
            .collection('feedbacks')
            .where('uid', isEqualTo: uid)
            .limit(200)
            .get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[withdraw] feedbacks cleanup failed: $e');
    }
  }

  /// ✅ 유저의 Firestore + Storage 전체 데이터 삭제 (회원탈퇴 시).
  ///
  /// 정리 순서:
  ///   1) 외부 컬렉션 (community_posts/reports, feedbacks) — 본인 uid 로 묶인 것
  ///   2) 사용자 서브컬렉션 (diary/call/notifications/insights)
  ///   3) Storage 의 users/{uid} 폴더 (그림일기 + 댓글 이미지 등)
  ///   4) FCM 토큰 무효화 (이 기기에 더 이상 push 가 오지 않게)
  ///   5) 마지막에 user 문서 자체 삭제
  Future<void> _deleteAllUserData(String uid) async {
    await _deleteUserOwnedExternalDocs(uid);

    // 사용자 서브컬렉션 (rules 의 wildcard 매치로 본인이 read/write 가능)
    await _deleteSubcollection(uid: uid, subcollectionName: 'diary');
    await _deleteSubcollection(uid: uid, subcollectionName: 'call');
    await _deleteSubcollection(uid: uid, subcollectionName: 'notifications');
    await _deleteSubcollection(uid: uid, subcollectionName: 'insights');

    // Storage: users/{uid} 통째로 (diaries, illustration, 그 외)
    try {
      await _deleteStorageFolder('users/$uid');
    } catch (e) {
      debugPrint('[withdraw] storage cleanup failed: $e');
    }

    // FCM 토큰 무효화 — auth 자체가 사라질 거라 user doc 의 fcmToken 필드는
    // 다음 단계 user doc 삭제로 같이 사라진다. 기기 측 토큰은 명시적으로 폐기.
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}

    // 마지막에 user 문서 삭제
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
  }

  /// 로그아웃/탈퇴 시 모든 사용자 의존 state 를 비운다.
  /// 같은 기기에서 다른 계정으로 로그인했을 때 이전 사용자의 메시지/설정/draft
  /// /통화 백업 등이 보이지 않게 하는 게 목적.
  Future<void> _clearLocalUserState(WidgetRef ref) async {
    // 인증/식별
    ref.read(userIdProvider.notifier).state = null;
    ref.invalidate(userProvider);
    // ignore: unawaited_futures
    AnalyticsService.setUserId(null);
    // ignore: unawaited_futures
    AnalyticsService.clearUserProperties();

    // 네비게이션 인덱스
    ref.read(MainIndexProvider.notifier).state = 0;

    // 통화 관련
    ref.invalidate(messageProvider);
    ref.invalidate(selectedVoiceProvider);

    // 일기 / 검색
    ref.invalidate(searchQueryProvider);

    // 온보딩 draft
    ref.invalidate(onboardingDraftProvider);

    // 진행 중이던 통화 백업이 다음 사용자에게 복구 배너로 노출되지 않게.
    try {
      await ConversationBackupService.clear();
    } catch (_) {}
  }

  /// 현재 기기의 FCM 토큰을 무효화하고 user doc 의 fcmToken 필드를 지운다.
  /// 로그아웃 시 다른 사용자의 푸시가 이 기기에 오지 않게 하는 용도.
  Future<void> _clearFcmTokenForLogout(String? uid) async {
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .doc('users/$uid')
            .update({'fcmToken': FieldValue.delete()});
      } catch (_) {}
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> handleWithdraw(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Future<bool> showWithdrawConfirmDialog(BuildContext context) async {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // 탈퇴는 false 추천. 원하면 true 유지
        barrierColor: Colors.black.withOpacity(0.45),
        builder: (_) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.grey[800]?.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '정말 회원탈퇴 하시겠어요?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '회원탈퇴 시 계정 정보와 저장된 데이터가 삭제되며 이 작업은 다시 되돌릴 수 없어요.\n\n탈퇴 과정에서 보안을 위해 재인증이 필요할 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '그냥 둘래요',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFD75B3A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '탈퇴할게요',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

      return result ?? false;
    }

    final confirm = await showWithdrawConfirmDialog(context);
    if (confirm != true) return;

    // 애플 계정은 탈퇴 시 애플 토큰 철회가 필수(App Store 5.1.1(v)) — 철회에
    // 방금 발급된 authorizationCode 가 필요해서 데이터 삭제 전에 재인증을 먼저
    // 한다. 여기서 취소하면 아무것도 지워지지 않은 상태로 탈퇴가 중단된다.
    if (_isAppleUser(user)) {
      try {
        await AppleAuthService().reauthenticateForWithdrawal();
      } catch (_) {
        if (context.mounted) {
          _showError(context, '재인증이 취소되어 탈퇴를 중단했어요');
        }
        return;
      }
      if (!context.mounted) return;
    }

    // 진행 중 다이얼로그 — 회원탈퇴는 Firestore 다중 컬렉션 정리 + Storage + auth
    // 까지 시간이 걸려서 사용자에게 "처리 중" 피드백을 명시적으로 줘야 한다.
    final dismiss = showGlassProgressDialog(
      context: context,
      message: '회원탈퇴 처리 중...',
    );

    try {
      final uid = user.uid;

      // 1) Firestore + Storage 전부 삭제 (community/inbox/insights/feedbacks 포함)
      await _deleteAllUserData(uid);

      // 2) Firebase Auth 계정 삭제
      await user.delete();

      // 3) Google 자동 재로그인 방지
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      // 4) 로컬 state 정리 + 통화 백업 정리
      await _clearLocalUserState(ref);

      dismiss();

      // 5) 로그인 화면으로 이동
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      // 재인증 흐름은 진행 다이얼로그를 닫고 안내 → 픽커 → 다시 진행 다이얼로그.
      dismiss();
      if (e.code == 'requires-recent-login') {
        if (!context.mounted) return;
        await _showReauthRequiredAwait(context);
        try {
          await _reauthenticateForWithdraw(user);
        } catch (_) {
          if (context.mounted) {
            _showError(context, '재인증이 취소되어 탈퇴를 중단했어요');
          }
          return;
        }
        // 재인증 성공 — 데이터 정리부터 다시. 진행 다이얼로그 다시 띄움.
        if (!context.mounted) return;
        final dismiss2 = showGlassProgressDialog(
          context: context,
          message: '회원탈퇴 처리 중...',
        );
        try {
          await _deleteAllUserData(user.uid);
          await user.delete();
          try {
            await GoogleSignIn().signOut();
          } catch (_) {}
          await _clearLocalUserState(ref);
          dismiss2();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
            );
          }
        } catch (e) {
          dismiss2();
          if (context.mounted) _showError(context, '$e');
        }
      } else {
        _showError(context, e.message);
      }
    } catch (e) {
      dismiss();
      _showError(context, e.toString());
    }
  }

  /// 글래스 톤 재인증 안내 다이얼로그. dialog 가 닫힐 때까지 await 한다 — 그 후에
  /// Google 픽커를 띄워야 두 UI 가 race 하지 않는다.
  ///
  /// 재인증은 Firebase 의 보안 정책 (`requires-recent-login`) 상 회피 불가능 —
  /// 마지막 로그인이 너무 오래된 사용자가 `user.delete()` 를 호출하면 무조건
  /// 이 에러가 나온다. 다이얼로그 자체는 머티리얼 `AlertDialog` 를 쓰지 않고
  /// 앱 톤의 글래스로 통일.
  Future<void> _showReauthRequiredAwait(BuildContext context) async {
    await showGlassDialog<void>(
      context: context,
      title: '다시 로그인이 필요해요',
      message: '보안을 위해 회원탈퇴를 진행하려면\n다시 로그인해 주세요.',
      barrierDismissible: false,
      actions: const [
        GlassDialogAction<void>(label: '확인', value: null, isPrimary: true),
      ],
    );
  }

  void _showError(BuildContext context, String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? '회원탈퇴 중 오류가 발생했습니다')),
    );
  }

  Future<void> handleLogout(BuildContext context, WidgetRef ref) async {
    final dismiss = showGlassProgressDialog(
      context: context,
      message: '로그아웃 처리 중...',
    );

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // 1) FCM 토큰 무효화 — 로그아웃 후 다른 사용자가 같은 기기에 로그인 시
      //    이전 계정의 push 가 오지 않게.
      await _clearFcmTokenForLogout(uid);

      // 2) Firebase + Google 로그아웃
      await FirebaseAuth.instance.signOut();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      // 3) 로컬 state + 통화 백업 정리
      await _clearLocalUserState(ref);

      dismiss();

      // 4) 로그인 화면으로
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      dismiss();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("로그아웃 실패: $e")),
        );
      }
    }
  }

  Future<void> _submitFeedback({
    required String feedback,
    required WidgetRef ref,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final user = ref.read(userProvider).valueOrNull; // 닉네임/이메일 등 같이 저장하고 싶을 때
    final info = await PackageInfo.fromPlatform();

    await FirebaseFirestore.instance.collection('feedbacks').add({
      'text': feedback.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'uid': uid,
      'email': FirebaseAuth.instance.currentUser?.email,
      'displayName': user?.email ?? user?.id, // 프로젝트 모델에 맞게
      'appVersion': info.version, // 원하면 package_info_plus로 채우기
      'buildNumber': info.buildNumber,
      'platform':
          Theme.of(ref.context).platform.name, // 또는 Platform.operatingSystem
      'status': 'new', // 처리 상태( new / in_progress / done )
    });
  }

  Future<String> _getVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('마이', style: TextStyle().copyWith(fontSize: 25)),
        centerTitle: false,
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return AuthErrorScreen();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: ListView(
              children: [
                const SizedBox(height: 20),
                const MyPlanetCard(),
                const SizedBox(height: 20),
                const MyRankCard(),
                const SizedBox(height: 20),
                _OpinionGiveMe(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      backgroundColor: deep_grey_blue_color,
                      builder:
                          (sheetContext) => FeedbackBottomSheet(
                            controller: _feedbackController,
                            onSubmit: () async {
                              final feedback = _feedbackController.text.trim();
                              if (feedback.isEmpty) return;
                              Navigator.of(sheetContext).pop();
                              try {
                                await _submitFeedback(
                                    feedback: feedback, ref: ref);
                                _feedbackController.clear();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('소중한 의견을 보내주셔서 감사해요')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('전송에 실패했어요: $e')),
                                  );
                                }
                              }
                            },
                          ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                ElevatedCardContainer(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      '고객지원',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SimpleTitleTile(
                      title: '자주 묻는 질문 (FAQ)',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => FAQScreen()));
                      },
                    ),
                    SimpleTitleTile(
                      title: '문의하기 / 고객센터',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => ContactSupportScreen()));
                      },
                    ),
                    SimpleTitleTile(
                      title: '공지사항',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => NoticeScreen()));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedCardContainer(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      '앱 설정',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SimpleTitleTile(
                      title: '내 정보',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ProfileEditScreen()),
                      ),
                    ),
                    SimpleTitleTile(
                      title: '알림 설정',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationSettingScreen()),
                      ),
                    ),
                    SimpleTitleTile(
                      title: '커뮤니티 설정',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const CommunitySettingsScreen()),
                      ),
                    ),
                    SimpleTitleTile(
                      title: '알림 즉시 표시 테스트',
                      onTap: () async {
                        // ✅ 즉시 알림 — _plugin.show() 가 정상 동작하는지 확인용.
                        //    실패 시 로그에 "[NOTI] ❌ 즉시 표시 실패: ..." 가 찍힘.
                        await LocalNotificationService.instance.showTestNow();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedCardContainer(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      '앱 정보',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 10),

                    SimpleTitleTile(
                      title: '앱 버전',
                      trailing: FutureBuilder<String>(
                        future: _getVersion(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          return Text(
                            snapshot.data!,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AppVersionScreen()),
                        );
                      },
                    ),

                    SimpleTitleTile(
                      title: '이용약관',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const TermsOfServiceScreen()),
                        );
                      },
                    ),
                    SimpleTitleTile(
                      title: '개인정보 처리방침',
                      // 노션 페이지를 외부 브라우저로 연다 — 인앱 화면 대신
                      // 링크로 관리해 내용 수정 시 앱 업데이트가 필요 없다.
                      onTap: () => openPrivacyPolicy(context),
                    ),

                  ],
                ),
                const SizedBox(height: 20),
                ElevatedCardContainer(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      '계정',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SimpleTitleTile(
                      title: '로그아웃',
                      onTap: () => handleLogout(context, ref),
                    ),
                    SimpleTitleTile(
                      title: '회원탈퇴',
                      onTap: () => handleWithdraw(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
        error:
            (err, _) => Center(
              child: Text('사용자 정보를 불러올 수 없습니다\n오류:$err', softWrap: true),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _OpinionGiveMe extends StatelessWidget {
  final VoidCallback onTap;

  const _OpinionGiveMe({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 100,
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 3),
                  Text(
                    '디어로그에서의 경험은 어떠셨나요?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '솔직한 의견을 들려주세요',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              Icon(IconsaxPlusLinear.edit, size: 35, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }
}
