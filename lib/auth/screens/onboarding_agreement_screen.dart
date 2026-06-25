import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dearlog/app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class OnboardingAgreementScreen extends StatefulWidget {
  const OnboardingAgreementScreen({super.key});

  @override
  State<OnboardingAgreementScreen> createState() =>
      _OnboardingAgreementScreenState();
}

class _OnboardingAgreementScreenState extends State<OnboardingAgreementScreen> {
  bool agreeAll = false;
  bool age14 = false;
  bool termsOfUse = false;
  bool privacyPolicy = false;
  bool marketingConsent = false;
  bool _saving = false;

  void toggleAll(bool? value) {
    setState(() {
      agreeAll = value ?? false;
      age14 = agreeAll;
      termsOfUse = agreeAll;
      privacyPolicy = agreeAll;
      marketingConsent = agreeAll;
    });
  }

  void checkIfAllAgreed() {
    setState(() {
      agreeAll = age14 && termsOfUse && privacyPolicy && marketingConsent;
    });
  }

  /// 약관 동의 정보를 user doc 에 영구 저장.
  /// 정보통신망법상 마케팅 옵트인은 시각 기록이 필요하므로 serverTimestamp 사용.
  Future<bool> _saveAgreements() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final now = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.doc('users/$uid').set({
        'agreedTermsAt': now,
        'agreedPrivacyAt': now,
        // 개인정보처리방침의 "만 14세 미만 미제공" 정책의 확인 근거.
        'age14ConfirmedAt': now,
        'marketingConsent': marketingConsent,
        if (marketingConsent) 'marketingConsentAt': now,
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('[onboarding] save agreements failed: $e');
      return false;
    }
  }

  Future<void> _handleConfirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await _saveAgreements();
    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('동의 저장에 실패했어요. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingNameScreen()),
    );
  }

  void _showMarketingDetail() {
    showGlassDialog<void>(
      context: context,
      title: '마케팅 정보 수신 동의',
      message:
          '디어로그는 새 기능 안내, 이벤트, 추천 콘텐츠 등 마케팅 정보를 앱 내 알림 또는 이메일로 보내드릴 수 있어요.\n\n동의는 선택 사항이며, 가입 후 [마이 → 알림 설정]에서 언제든 철회할 수 있어요.',
      actions: const [
        GlassDialogAction<void>(label: '확인', value: null, isPrimary: true),
      ],
    );
  }

  /// 약관 동의 화면에서 뒤로가기 시 — 동의를 거부한 것으로 보고 로그아웃 + LoginScreen.
  /// (그대로 두면 빈 검은 화면이 보이거나, 다시 진입 시 동의 단계가 건너뛰어짐)
  Future<void> _handleBack() async {
    try {
      await FirebaseAuth.instance.signOut();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = age14 && termsOfUse && privacyPolicy;

    return PopScope(
      // 시스템/제스처 백 → 우리 _handleBack 으로 라우팅 (LoginScreen 으로 정상 복귀)
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: BaseScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white,),
          onPressed: _handleBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              ' 서비스 이용 동의',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 40),

            buildAgreementItem(
              title: '약관 전체동의',
              value: agreeAll,
              onChanged: toggleAll,
              isBold: true,
            ),
            const Divider(),
            buildAgreementItem(
              title: '(필수) 만 14세 이상입니다',
              value: age14,
              onChanged: (val) {
                setState(() => age14 = val ?? false);
                checkIfAllAgreed();
              },
            ),
            buildAgreementItem(
              title: '(필수) 서비스 이용약관',
              value: termsOfUse,
              onChanged: (val) {
                setState(() => termsOfUse = val ?? false);
                checkIfAllAgreed();
              },
              onTapDetail: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const TermsOfServiceScreen()),
                );
              },
            ),
            buildAgreementItem(
              title: '(필수) 개인정보 처리방침',
              value: privacyPolicy,
              onChanged: (val) {
                setState(() => privacyPolicy = val ?? false);
                checkIfAllAgreed();
              },
              // 개인정보 처리방침은 노션 페이지 — 외부 브라우저로 연다.
              onTapDetail: () => openPrivacyPolicy(context),
            ),
            buildAgreementItem(
              title: '(선택) 마케팅 정보 수신동의',
              value: marketingConsent,
              onChanged: (val) {
                setState(() => marketingConsent = val ?? false);
                checkIfAllAgreed();
              },
              onTapDetail: _showMarketingDetail,
            ),
            const Spacer(),
            GestureDetector(
              onTap: (enabled && !_saving) ? _handleConfirm : null,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: enabled ? Colors.green[400] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '확인',
                          style: TextStyle(
                            color: enabled ? Colors.white : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
      ),
    );
  }

  Widget buildAgreementItem({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
    bool isBold = false,
    VoidCallback? onTapDetail,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green[400],
            side: BorderSide(color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: Colors.white
              ),
            ),
          ),
          if (onTapDetail != null)
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white,),
              onPressed: onTapDetail,
            ),
        ],
      ),
    );
  }
}
