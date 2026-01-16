import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dearlog/app.dart';

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
    final diary = DiaryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      title: diaryJson['title'],
      content: diaryJson['content'],
      emotion: diaryJson['emotion'],
      imageUrls: [imageUrl],
      callId: callId,
    );

    final analysis = await generateAnalysisFromDiary(diary);

    return diary.copyWith(analysis: analysis);
  }
}


extension OpenAIAnalysis on OpenAIService {
  Future<DiaryAnalysis> generateAnalysisFromDiary(DiaryEntry diary) async {
    final promptMessages = [
      {
        "role": "system",
        "content": '''
너는 감정 분석 리포트 생성기야.
아래 일기 내용을 바탕으로 "오늘의 감정 분석"을 JSON으로만 출력해.

반드시 아래 스키마를 지켜:
{
  "summary": "한 줄 요약(공감 톤)",
  "moodScore": 0~100 정수 (낮을수록 힘듦),
  "valence": "positive" | "neutral" | "negative",
  "emotions": [
    {"name":"감정명", "score":0~100, "keywords_emotion":["키워드","키워드"]},
    ... (최대 3개)
  ],
  "evidence": [
    {"quote":"일기에서 근거 문장 일부", "why":"어떤 감정 근거인지"},
    ... (최대 3개)
  ],
  "recommendations": [{
    "title":"행동 제안 제목",
    "minutes":3|10|20|30,
    "type":"solo" | "content" | "support",
    "fromEmotion":"불안",
    "toEmotion":"안정",
    "why":"감정/근거와 연결된 한 줄 이유",
    "steps":["단계1","단계2","단계3(선택)"],
    "ctaLabel":"(선택) 앱에서 해보기 버튼 라벨",
    "deeplink":"(선택) 앱 내부 경로"
    },
    ... (정확히 3개)
  ],
  "riskLevel": "low" | "medium" | "high",
  "mainWords": ["핵심어1","핵심어2","핵심어3"],
}

mainWords 규칙:
- 반드시 3개
- 2~6글자의 명사/명사구 위주
- '하루','오늘','아침','저녁','시간','일상','보냈다','생각','느낌' 같은 일반어/서술어 금지
- 주제 단어를 우선: 일정/마감/공부/시험/관계/가족/친구/수면/건강/운동/돈/소비 등
- 일기 내용을 바탕으로 핵심어를 추출할 것

recommendations 규칙:
- 정확히 3개.
- 최소 2개는 type="solo" (혼자 지금 당장 가능, 1~5분 권장)
- 최소 1개는 type="content" (앱 내에서 할 수 있는 것: 음악/짧은 질문/감정 정리 등)
- type="support"는 riskLevel이 medium/high일 때만 포함 가능. 포함하더라도 "가능하다면/원한다면" 같은 부담 낮은 표현으로.
- steps는 2~4개. 각 step은 시간/행동이 구체적이어야 함.
- why는 emotions/evidence/mainWords 중 최소 1개를 반영한 문장.

주의:
- 진단/의료 판단처럼 말하지 마.
- JSON 외 텍스트 금지.
'''
      },
      {
        "role": "user",
        "content": "일기 제목: ${diary.title}\n감정 라벨: ${diary.emotion}\n일기 내용:\n${diary.content}"
      }
    ];

    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "gpt-4.1-mini",
        "messages": promptMessages,
        "max_tokens": 10000,
        "temperature": 0.4,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('분석 생성 실패: ${res.body}');
    }

    final content = jsonDecode(res.body)['choices'][0]['message']['content'];
    final jsonMap = jsonDecode(content);
    return DiaryAnalysis.fromJson(Map<String, dynamic>.from(jsonMap));
  }
}
