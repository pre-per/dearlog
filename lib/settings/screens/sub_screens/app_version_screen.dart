import 'package:dearlog/app.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionScreen extends StatelessWidget {
  const AppVersionScreen({super.key});

  Future<PackageInfo> _getVersion() async {
    return await PackageInfo.fromPlatform();
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
            FutureBuilder<PackageInfo>(
              future: _getVersion(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text(
                    '버전 정보 불러오는 중...',
                    style: TextStyle(fontSize: 18),
                  );
                }

                final info = snapshot.data!;
                return _VersionGestureDetector(
                  title: '버전 정보 ${info.version} (${info.buildNumber})',
                  onTap: () {},
                );
              },
            ),
            _VersionGestureDetector(title: '앱이 최신 버전입니다.', onTap: () {},)
          ],
        ),
      ),
    );
  }
}

class _VersionGestureDetector extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _VersionGestureDetector({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
        child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),),
      ),
    );
  }
}
