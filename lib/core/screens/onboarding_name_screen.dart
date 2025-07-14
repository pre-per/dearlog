import 'package:dearlog/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/models/user_profile.dart';
import '../../user/repository/user_repository.dart';

class OnboardingNameScreen extends ConsumerStatefulWidget {
  const OnboardingNameScreen({super.key});

  @override
  ConsumerState<OnboardingNameScreen> createState() =>
      _NicknameInputScreenState();
}

class _NicknameInputScreenState extends ConsumerState<OnboardingNameScreen> {
  final TextEditingController _controller = TextEditingController();
  String nickname = '';

  bool get isValid {
    final regex = RegExp(r'^[가-힣a-zA-Z0-9._]{1,12}$');
    return regex.hasMatch(nickname);
  }

  void clearInput() {
    _controller.clear();
    setState(() {
      nickname = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '디어로그에서 사용할\n이름을 입력해주세요.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '이름은 공백없이 12자 이하,\n기호는 _ . 만 사용 가능합니다.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _controller,
              onChanged: (val) {
                setState(() {
                  nickname = val;
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                hintText: '닉네임 입력',
                suffixIcon:
                    nickname.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.cancel),
                          onPressed: clearInput,
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLength: 12,
              style: const TextStyle(fontSize: 18),
            ),
            const Spacer(),
            GestureDetector(
              onTap:
                  isValid
                      ? () async {
                        final userId = FirebaseAuth.instance.currentUser!.uid;
                        final repo = UserRepository();

                        final newProfile = UserProfile(
                          nickname: nickname,
                          age: 0,
                          gender: '',
                          location: '',
                        );

                        await repo.saveProfile(userId, newProfile);

                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const MainScreen()),
                        );
                      }
                      : null,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: isValid ? Colors.green[400] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '확인',
                    style: TextStyle(
                      color: isValid ? Colors.white : Colors.black,
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
}
