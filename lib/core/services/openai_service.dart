import '../../call/models/conversation/chat_response.dart';
import '../../call/models/conversation/message.dart';
import '../../diary/models/diary_entry.dart';
import 'remote_config_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  final _apiKey = RemoteConfigService().openAIApiKey;

  Future<ChatResponse> getChatResponse(List<Message> messages) async {
    const url = 'https://api.openai.com/v1/chat/completions';

    final allMessages = [
      {
        "role": "system",
        "content": "너는 사용자의 하루를 따뜻하게 들어주는 친구야. 1~2줄로 짧고 공감 있게 대답하고, 통화 중이라는 상황을 인지하고 항상 자연스러운 질문으로 대화를 이어가줘."
      },
      ...messages.map((msg) => {"role": msg.role, "content": msg.content})
    ];

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "gpt-4.1-mini-2025-04-14",
        "messages": allMessages,
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

  Future<DiaryEntry> generateDiaryFromMessages(List<Message> messages) async {
    final promptMessages = [
      {
        "role": "system",
        "content":
        '''너는 일기 작성 도우미야. 다음 대화를 바탕으로 사용자의 하루를 요약해서 아래와 같은 JSON 형식으로 응답해줘:
          
          {
            "title": "일기 제목",
            "emotion": "행복, 기쁨, 슬픔, 불안, 분노 중 하나", 
            "content": "일기 내용은 사용자가 직접 쓴 것처럼 5~7문장으로.",
          }
          
          JSON 외의 말은 하지 마.'''
      },
      ...messages.map((msg) => {"role": msg.role, "content": msg.content}),
    ];


    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "gpt-4.1-mini",
        "messages": promptMessages,
        "max_tokens": 400,
        "temperature": 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body);
      final content = jsonBody['choices'][0]['message']['content'];

      final Map<String, dynamic> diaryJson = jsonDecode(content);

      return DiaryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // 또는 UUID
        date: DateTime.now(),
        title: diaryJson['title'],
        content: diaryJson['content'],
        emotion: diaryJson['emotion'],
        imageUrls: ['https://images.unsplash.com/photo-1506744038136-46273834b3fb'],
      );
    } else {
      throw Exception('일기 생성 실패: ${response.body}');
    }
  }

}