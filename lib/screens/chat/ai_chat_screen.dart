import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('안녕? 나는 디어로그야!'),
      ),
    );
  }
}
