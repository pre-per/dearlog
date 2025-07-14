import 'package:dearlog/core/screens/login_screen.dart';
import 'package:flutter/material.dart';

import 'onboarding_name_screen.dart';

class OnboardingAgreementScreen extends StatefulWidget {
  const OnboardingAgreementScreen({super.key});

  @override
  State<OnboardingAgreementScreen> createState() =>
      _OnboardingAgreementScreenState();
}

class _OnboardingAgreementScreenState extends State<OnboardingAgreementScreen> {
  bool agreeAll = false;
  bool termsOfUse = false;
  bool privacyPolicy = false;
  bool marketingConsent = false;

  void toggleAll(bool? value) {
    setState(() {
      agreeAll = value ?? false;
      termsOfUse = agreeAll;
      privacyPolicy = agreeAll;
      marketingConsent = agreeAll;
    });
  }

  void checkIfAllAgreed() {
    setState(() {
      agreeAll = termsOfUse && privacyPolicy && marketingConsent;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = termsOfUse && privacyPolicy;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
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
              title: '(필수) 서비스 이용약관',
              value: termsOfUse,
              onChanged: (val) {
                setState(() => termsOfUse = val ?? false);
                checkIfAllAgreed();
              },
              onTapDetail: () {},
            ),
            buildAgreementItem(
              title: '(필수) 개인정보 처리방침',
              value: privacyPolicy,
              onChanged: (val) {
                setState(() => privacyPolicy = val ?? false);
                checkIfAllAgreed();
              },
              onTapDetail: () {},
            ),
            buildAgreementItem(
              title: '(선택) 마케팅 정보 수신동의',
              value: marketingConsent,
              onChanged: (val) {
                setState(() => marketingConsent = val ?? false);
                checkIfAllAgreed();
              },
              onTapDetail: () {},
            ),
            const Spacer(),
            GestureDetector(
              onTap:
                  enabled
                      ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OnboardingNameScreen(),
                        ),
                      )
                      : null,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: enabled ? Colors.green[400] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
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
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          if (onTapDetail != null)
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: onTapDetail,
            ),
        ],
      ),
    );
  }
}
