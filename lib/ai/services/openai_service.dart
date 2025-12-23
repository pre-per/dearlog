import '../../call/models/conversation/chat_response.dart';
import '../../call/models/conversation/message.dart';
import '../../core/config/remote_config_service.dart';
import '../../diary/models/diary_entry.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  final _apiKey = RemoteConfigService().openAIApiKey;

  Future<ChatResponse> getChatResponse(List<Message> messages) async {
    const url = 'https://api.openai.com/v1/chat/completions';

    final allMessages = [
      {
        "role": "system",
        "content": "너는 사용자의 하루를 따뜻하게 들어주는 친구야. 1~2줄로 짧고 공감 있게 대답하고, 통화 중이라는 상황을 인지하고 항상 자연스럽게 대화를 이어가줘."
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
        "model": "gpt-4.1-mini",
        "messages": allMessages,
        "max_tokens": 400,
        "temperature": 0.7,
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

  Future<DiaryEntry> generateDiaryFromMessages(List<Message> messages, {String? callId}) async {
    // 1단계: 일기 요약 요청
    final promptMessages = [
      {
        "role": "system",
        "content": '''
너는 일기 작성 도우미야. 다음 대화를 바탕으로 사용자의 하루를 요약해서 아래와 같은 JSON 형식으로 응답해줘:

{
  "title": "일기 제목",
  "emotion": "슬픔, 외로움, 우울, 평온, 안정, 차분, 분노, 짜증, 답답함, 기쁨, 설렘, 즐거움, 행복, 만족, 감사 중 하나", 
  "content": "일기 내용은 사용자가 직접 쓴 것처럼 5~7문장으로."
}

JSON 외의 말은 하지 마.
'''
      },
      ...messages.map((msg) => {"role": msg.role, "content": msg.content}),
    ];

    final diaryResponse = await http.post(
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

    if (diaryResponse.statusCode != 200) {
      throw Exception('일기 생성 실패: ${diaryResponse.body}');
    }

    final diaryContent = jsonDecode(diaryResponse.body)['choices'][0]['message']['content'];
    final diaryJson = jsonDecode(diaryContent);

    // 2단계: 그림 이미지 생성 요청 (내용 기반)
    final imagePrompt =
    '''
    다음 내용을 바탕으로 파스텔톤 색감의 그림 일기 스타일 일러스트를 한 장면으로 그려줘.
    가운데에는 동그란 형태의 귀엽고 단순한 캐릭터 하나만 등장하게 하고, 주변 배경은 잔잔하고 따뜻한 분위기로 구성해줘.
    장면은 하나의 통일된 공간(예: 방, 공원, 거리 등) 안에서 이루어져야 하며, 여러 장면을 분할하거나 나누지 말고 하나의 전체 그림으로 그려줘.
    전체적으로 손으로 그린 듯한 느낌을 주고, 만화처럼 선이 부드럽고 질감이 연하게 표현되었으면 좋겠어.
    캐릭터의 표정과 행동은 글의 분위기와 감정을 반영하도록 해줘.
    다음은 참고할 내용이야: ${diaryJson['content']}
    ''';


    final imageResponse = await http.post(
      Uri.parse('https://api.openai.com/v1/images/generations'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "dall-e-3",
        "prompt": imagePrompt,
        "n": 1,
        "size": "1024x1024",
      }),
    );

    if (imageResponse.statusCode != 200) {
      throw Exception('그림 생성 실패: ${imageResponse.body}');
    }

    final imageUrl = jsonDecode(imageResponse.body)['data'][0]['url'];

    // 최종 DiaryEntry 반환
    return DiaryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      title: diaryJson['title'],
      content: diaryJson['content'],
      emotion: diaryJson['emotion'],
      imageUrls: [imageUrl],
      callId: callId,
    );
  }
}
