import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 개인정보 처리방침 — 노션 페이지로 관리한다.
/// 인앱 화면 대신 외부 브라우저로 열어, 내용 수정 시 앱 업데이트 없이 반영된다.
/// (App Store Connect 의 Privacy Policy URL 메타데이터에도 같은 링크를 사용)
const String kPrivacyPolicyUrl =
    'https://meadow-car-a48.notion.site/Dearlog-Privacy-Policy-37d0c3941c19803681d3cc85ed917c68?source=copy_link';

/// 개인정보 처리방침을 외부 브라우저(앱 밖)로 연다.
Future<void> openPrivacyPolicy(BuildContext context) async {
  final uri = Uri.parse(kPrivacyPolicyUrl);
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('링크를 열 수 없어요. 잠시 후 다시 시도해 주세요.')),
    );
  }
}
