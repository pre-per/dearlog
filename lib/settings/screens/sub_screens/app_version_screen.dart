import 'dart:convert';
import 'package:dearlog/app.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AppVersionScreen extends StatefulWidget {
  const AppVersionScreen({super.key});

  @override
  State<AppVersionScreen> createState() => _AppVersionScreenState();
}

class _AppVersionScreenState extends State<AppVersionScreen> {
  PackageInfo? _info;
  String? _latestVersion;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _info = info);
    _checkUpdate(info);
  }

  Future<void> _checkUpdate(PackageInfo info) async {
    setState(() => _checking = true);
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/lookup?bundleId=${info.packageName}&country=kr',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = json['results'] as List?;
      if (results != null && results.isNotEmpty) {
        setState(() => _latestVersion = results[0]['version'] as String?);
      }
    } catch (_) {
      // 네트워크 오류 무시
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openAppStore() async {
    if (_info == null) return;
    final uri = Uri.parse(
      'https://itunes.apple.com/search?term=dearlog&entity=software&country=kr',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _copyVersion() {
    if (_info == null) return;
    Clipboard.setData(ClipboardData(text: '${_info!.version} (${_info!.buildNumber})'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('버전 정보가 복사되었습니다.', style: TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool get _isOutdated {
    if (_latestVersion == null || _info == null) return false;
    return _latestVersion! != _info!.version;
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              '앱 버전',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 28),
            ),
            const SizedBox(height: 40),
            _VersionGestureDetector(
              title: _info == null
                  ? '버전 정보 불러오는 중...'
                  : '버전 정보 ${_info!.version} (${_info!.buildNumber})',
              subtitle: '탭하면 버전 정보가 복사됩니다.',
              onTap: _copyVersion,
            ),
            _VersionGestureDetector(
              title: _checking
                  ? '업데이트 확인 중...'
                  : _isOutdated
                      ? '새 버전이 있어요 → $_latestVersion'
                      : '최신 버전입니다.',
              subtitle: _isOutdated ? '탭하면 앱스토어로 이동합니다.' : null,
              onTap: _isOutdated ? _openAppStore : null,
              highlight: _isOutdated,
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionGestureDetector extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool highlight;

  const _VersionGestureDetector({
    required this.title,
    this.subtitle,
    this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: highlight ? const Color(0xFFFFD700) : null,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
