import 'package:dearlog/app.dart';

class CallRecordScreen extends ConsumerWidget {
  final String callId;

  const CallRecordScreen({super.key, required this.callId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCall = ref.watch(findCallProvider(callId));

    return BaseScaffold(
      appBar: AppBar(),
      body: asyncCall.when(
        data: (call) {
          if (call == null) {
            return const Center(child: Text('통화 기록을 찾을 수 없습니다.'));
          }

          final messages = call.messages;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return MessageBubble(message: messages[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('오류 발생: $e')),
      ),
    );
  }
}
