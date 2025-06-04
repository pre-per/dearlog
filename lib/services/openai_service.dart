import '../models/conversation/chat_response.dart';
import '../models/conversation/message.dart';
import '../services/remote_config_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  final _apiKey = RemoteConfigService().openAIApiKey;

  Future<ChatResponse> getChatResponse(String userInput) async {
    const url = 'https://api.openai.com/v1/chat/completions';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "gpt-4.1-mini",
        "messages": [
          {"role": "system", "content": "너는 공감 잘해주는 대화 상대야. 사용자와 직접 통화하듯이 답변을 짧게 해주고, 질문을 지속적으로 던져서 대화가 이어지게 해줘."},
          {"role": "user", "content": userInput}
        ],
        "max_tokens": 200,
        "temperature": 0.8,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final reply = json['choices'][0]['message']['content'];
      final tokenCount = json['usage']['total_tokens'] ?? 0;

      return ChatResponse(
        message: Message(role: 'assistant', content: reply.trim()),
        totalTokens: tokenCount,
      );
    } else {
      throw Exception('OpenAI 응답 실패: ${response.body}');
    }
  }

}
