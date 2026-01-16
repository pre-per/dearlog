import 'dart:io';

import 'package:flutter/services.dart';
import 'package:dearlog/app.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  static const String supportEmail = 'dearlogofficial@gmail.com'; // TODO: 너 메일로 변경
  static const String emailSubject = '[디어로그 문의]';

  Future<Map<String, String>> _getAppMeta() async {
    final info = await PackageInfo.fromPlatform();

    final os = Platform.isIOS
        ? 'iOS'
        : Platform.isAndroid
        ? 'Android'
        : Platform.operatingSystem;

    return {
      'appName': info.appName,
      'packageName': info.packageName,
      'version': info.version,
      'buildNumber': info.buildNumber,
      'os': os,
    };
  }

  Future<void> _openEmailApp(BuildContext context) async {
    try {
      final meta = await _getAppMeta();

      final body = '''
문의 내용을 아래에 작성해주세요.

------------------------
[앱 정보]
앱: ${meta['appName']}
버전: ${meta['version']} (${meta['buildNumber']})
OS: ${meta['os']}
패키지: ${meta['packageName']}
------------------------

[문의 내용]
''';

      final uri = Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: {
          'subject': emailSubject,
          'body': body,
        },
      );

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('메일 앱을 열 수 없어요. 이메일 주소를 복사해 직접 보내주세요.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메일 앱 열기 실패: $e')),
        );
      }
    }
  }

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일 주소가 복사되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      appBar: AppBar(
        title: const Text('문의하기 / 고객센터'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 16),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            const Text(
              '디어로그 이용 중 불편한 점이나\n궁금한 점이 있다면 아래로 문의해주세요.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '답변은 평일 기준 순차적으로 진행되며, 상황에 따라 1~3일 정도 소요될 수 있어요.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),

            _SupportCard(
              title: '이메일 문의',
              subtitle: '아래 이메일로 문의를 보내주세요.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const SelectableText(
                    supportEmail,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openEmailApp(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            '메일 앱 열기',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _copyEmail(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            '이메일 복사',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '메일 내용에 앱 버전/OS 정보가 자동으로 포함됩니다.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.grey[300],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _SupportCard(
              title: '자주 묻는 질문',
              subtitle: '간단한 질문은 FAQ에서 더 빠르게 해결할 수 있어요.',
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FAQScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: const Text(
                    'FAQ 보러가기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // (선택) 하단 “서비스 정보” 작은 텍스트
            FutureBuilder<Map<String, String>>(
              future: _getAppMeta(),
              builder: (context, snapshot) {
                final meta = snapshot.data;
                final versionText =
                meta == null ? '' : 'v${meta['version']} (${meta['buildNumber']})';

                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    versionText.isEmpty ? '디어로그' : '디어로그  •  $versionText',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SupportCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 카드 디자인: 살짝 어두운 바탕 + 은은한 테두리 + 둥근 모서리
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: deep_grey_blue_color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
