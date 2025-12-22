import 'package:dearlog/app.dart';

class AuthErrorScreen extends StatelessWidget {
  const AuthErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout, size: 80, color: Colors.grey),
              SizedBox(height: 20),
              Text(
                '세션이 만료되었어요',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                '다시 로그인해주세요.\n사용자 정보를 불러올 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              SizedBox(height: 40),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => LoginScreen()),
                  );
                },
                child: Container(
                  height: 50,
                  width: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.green[200],
                  ),
                  child: Center(
                    child: Text('로그인 하러 가기', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
