import 'dart:ui';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dearlog/app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingMainScreen extends ConsumerWidget {
  const SettingMainScreen({super.key});

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

  /// ✅ 유저의 Firestore + Storage 전체 데이터 삭제
  Future<void> _deleteAllUserData(String uid) async {
    // 1) Firestore 서브컬렉션 삭제 (call, diary)
    await _deleteSubcollection(uid: uid, subcollectionName: 'diary');
    await _deleteSubcollection(uid: uid, subcollectionName: 'call');

    // (선택) 외부 컬렉션도 uid로 묶여 있으면 삭제 가능
    // 예: feedbacks
    // final fb = await FirebaseFirestore.instance
    //     .collection('feedbacks')
    //     .where('uid', isEqualTo: uid)
    //     .get();
    // final batch = FirebaseFirestore.instance.batch();
    // for (final d in fb.docs) {
    //   batch.delete(d.reference);
    // }
    // await batch.commit();

    // 2) Storage 삭제: users/{uid}/diaries 아래 전부
    await _deleteStorageFolder('users/$uid/diaries');

    // 3) 마지막에 user 문서 삭제
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
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

    try {
      final uid = user.uid;

      // 1️⃣ Firestore 사용자 데이터 삭제
      // ✅ Firestore + Storage 전부 삭제
      await _deleteAllUserData(uid);

      // 2️⃣ Firebase Auth 계정 삭제
      await user.delete();

      // 3️⃣ Riverpod 상태 초기화
      ref.read(userIdProvider.notifier).state = null;
      ref.invalidate(userProvider);

      // 4️⃣ 로그인 화면으로 이동
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showReauthRequired(context);
        // 1) 재인증 시도
        await _reauthenticateWithGoogle();
        // 2) 재시도
        await user.delete();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
          );
        }
      } else {
        _showError(context, e.message);
      }
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  void _showReauthRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('다시 로그인 필요'),
          content: const Text(
            '보안을 위해 회원탈퇴를 진행하려면\n다시 로그인해 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _showError(BuildContext context, String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? '회원탈퇴 중 오류가 발생했습니다')),
    );
  }

  void handleLogout(BuildContext context, WidgetRef ref) async {
    try {
      await FirebaseAuth.instance.signOut(); // Firebase 로그아웃
      ref.read(userIdProvider.notifier).state = null; // 상태 초기화
      ref.invalidate(userProvider); // 사용자 정보 캐시 제거

      // 로그인 화면으로 이동
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("로그아웃 실패: $e")));
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
    final _feedbackController = TextEditingController();

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
                          (context) => FeedbackBottomSheet(
                            controller: _feedbackController,
                            onSubmit: () {
                              final feedback = _feedbackController.text;
                              _submitFeedback(feedback: feedback, ref: ref);
                              Navigator.of(context).pop();
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
                    SimpleTitleTile(title: '알림 설정 (Beta)'),
                    SimpleTitleTile(
                      title: '알림 테스트하기 (Beta) [10s]',
                      onTap: () async {
                        debugPrint('test tapped');
                        await LocalNotificationService.instance
                            .scheduleTestIn10Seconds();
                        debugPrint('showTestNow called');
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
                      title: '이용약관 & 개인정보 처리방침',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PrivacyPolicyScreen()),
                        );
                      },
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
