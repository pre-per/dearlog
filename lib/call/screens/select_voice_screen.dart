import 'package:dearlog/app.dart';
import 'package:dearlog/call/providers/voice_provider.dart';
import 'package:dearlog/call/screens/ai_chat_screen.dart';

class SelectVoiceScreen extends ConsumerWidget {
  const SelectVoiceScreen({super.key});

  static const List<String> voices = [
    'alloy', 'ash', 'ballad', 'cedar', 'coral', 'echo', 
    'fable', 'marin', 'nova', 'onyx', 'sage', 'shimmer', 'verse'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseScaffold(
      appBar: AppBar(
        title: const Text("AI 목소리 선택", style: TextStyle(color: Colors.white, fontFamily: 'GowunBatang')),
        backgroundColor: Colors.transparent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: voices.length,
        itemBuilder: (context, index) {
          final voice = voices[index];
          final isSelected = ref.watch(selectedVoiceProvider) == voice;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              title: Text(voice, style: const TextStyle(color: Colors.white, fontSize: 16)),
              trailing: isSelected ? const Icon(Icons.check, color: Colors.orangeAccent) : null,
              onTap: () {
                ref.read(selectedVoiceProvider.notifier).state = voice;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AiChatScreen()),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
