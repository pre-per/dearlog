import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:dearlog/app.dart';

String _stripCodeFence(String content) {
  final s = content.trim();
  final match = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(s);
  return match != null ? match.group(1)!.trim() : s;
}

class OpenAIService {
  final _apiKey = RemoteConfigService().openAIApiKey;

  Future<ChatResponse> getChatResponse(List<Message> messages) async {
    const url = 'https://api.openai.com/v1/chat/completions';

    final allMessages = [
      {
        "role": "system",
        "content": "너는 사용자의 하루를 따뜻하게 들어주는 친구야. 1~2줄 정도로 너가 진짜 사람인 것처럼 자연스럽게 대화를 이어나가줘."
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
        "model": "gpt-5.4-nano",
        "messages": allMessages,
        "max_completion_tokens": 400,
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

  /// GPT 응답을 token 단위로 스트리밍한다.
  /// 각 yield는 GPT가 생성한 텍스트 조각이다.
  Stream<String> streamChatTokens(List<Message> messages) async* {
    const url = 'https://api.openai.com/v1/chat/completions';

    final allMessages = [
      {
        "role": "system",
        "content": "너는 사용자의 하루를 따뜻하게 들어주는 친구야. 1~2줄 정도로 너가 진짜 사람인 것처럼 자연스럽게 대화를 이어나가줘."
      },
      ...messages
          .where((m) => m.content != '__loading__')
          .map((m) => {"role": m.role, "content": m.content}),
    ];

    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll({
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode({
      "model": "gpt-5.4-nano",
      "messages": allMessages,
      "max_completion_tokens": 400,
      "temperature": 0.7,
      "stream": true,
    });

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        throw Exception('OpenAI 스트리밍 실패(${streamedResponse.statusCode}): $body');
      }

      // SSE 라인 버퍼 (청크가 라인 경계와 다를 수 있음)
      final lineBuffer = StringBuffer();

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        lineBuffer.write(chunk);
        final raw = lineBuffer.toString();
        lineBuffer.clear();

        final lines = raw.split('\n');
        // 마지막 줄은 불완전할 수 있으므로 버퍼에 유지
        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (!line.startsWith('data: ')) continue;
          final jsonStr = line.substring(6).trim();
          if (jsonStr == '[DONE]') return;
          if (jsonStr.isEmpty) continue;
          try {
            final json = jsonDecode(jsonStr);
            final content = json['choices']?[0]?['delta']?['content'] as String?;
            if (content != null && content.isNotEmpty) yield content;
          } catch (_) {}
        }
        if (lines.last.isNotEmpty) lineBuffer.write(lines.last);
      }
    } finally {
      client.close();
    }
  }

  Future<DiaryEntry> generateDiaryFromMessages(List<Message> messages, {String? callId, void Function(int step)? onStep}) async {
    // 1단계: 일기 요약 및 AI 위로 한마디 생성 요청
    onStep?.call(1);
    final promptMessages = [
      {
        "role": "system",
        "content": '''
너는 일기 작성 도우미야. 다음 대화를 바탕으로 사용자의 하루를 요약해서 아래와 같은 JSON 형식으로 응답해줘:

{
  "title": "일기 제목",
  "emotion": "슬픔, 외로움, 우울, 평온, 안정, 차분, 분노, 짜증, 답답함, 기쁨, 설렘, 즐거움, 행복, 만족, 감사 중 하나", 
  "content": "일기 내용은 사용자가 직접 쓴 것처럼 5~7문장으로.",
  "aiComment": "사용자의 하루를 응원하거나 위로해 주는 따뜻한 한 마디 (1~2문장)"
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
        "model": "gpt-5.4-mini",
        "messages": promptMessages,
        "max_completion_tokens": 600,
        "temperature": 0.7,
        "response_format": {"type": "json_object"},
      }),
    );

    if (diaryResponse.statusCode != 200) {
      throw Exception('일기 생성 실패: ${diaryResponse.body}');
    }

    final diaryContent = jsonDecode(diaryResponse.body)['choices'][0]['message']['content'];
    final diaryJson = jsonDecode(_stripCodeFence(diaryContent));

    // 2단계: 감정 분석 생성 (mainWords를 이미지 프롬프트에 활용하기 위해 먼저 수행)
    onStep?.call(2);
    final title = diaryJson['title'] as String? ?? '';
    final content = diaryJson['content'] as String? ?? '';
    final emotion = diaryJson['emotion'] as String? ?? '';

    final diaryForAnalysis = DiaryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      title: title,
      content: content,
      emotion: emotion,
      aiComment: diaryJson['aiComment'] as String? ?? '',
      imageUrls: [],
      callId: callId,
    );
    final analysis = await generateAnalysisFromDiary(diaryForAnalysis);

    // 3단계: 그림 이미지 생성 (mainWords 포함)
    onStep?.call(3);
    final mainWordsStr = analysis.mainWords.join(', ');

    final imagePrompt = '''
You are illustrating a single-scene pastel-style diary illustration for a Korean user's daily journal entry.

[DIARY INFO]
- Title: $title
- Emotion: $emotion
- Key themes: $mainWordsStr
- Content: $content

[ILLUSTRATION RULES]
1. Scene: Choose ONE specific location or moment from the content (e.g., a cozy room, a café, a park bench, a bed at night). The scene must directly reflect a concrete detail mentioned in the content — not a generic setting.
2. Character: One small, round, simple cartoon character at the center. The character's pose, action, and facial expression must reflect the emotion ("$emotion") and what they are doing in the story.
3. Key objects: Identify 3–5 concrete nouns or actions from the content (e.g., a book, a phone call, music notes, food, a friend, rain, a TV) and include them visually in the scene as props or background details. Prioritize objects related to the key themes: $mainWordsStr.
4. Storytelling details: Scatter small visual storytelling elements throughout — things like: items on a desk, what's outside the window, objects on the floor, or subtle symbols that hint at what happened that day.
5. Style: Soft pastel color palette, hand-drawn feel, smooth rounded lines, light texture. Warm and gentle mood. No text or letters in the image.
6. Composition: Single unified scene, no split panels. The illustration should feel like one complete, lived-in moment — not a generic or symbolic image.
''';

    final imageResponse = await http.post(
      Uri.parse('https://api.openai.com/v1/images/generations'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "gpt-image-1.5",
        "prompt": imagePrompt,
        "n": 1,
        "size": "1024x1024",
      }),
    );

    if (imageResponse.statusCode != 200) {
      throw Exception('그림 생성 실패: ${imageResponse.body}');
    }

    final b64 = jsonDecode(imageResponse.body)['data'][0]['b64_json'] as String;
    final imageBytes = base64Decode(b64);
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('diary_images/${DateTime.now().millisecondsSinceEpoch}.png');
    await storageRef.putData(imageBytes, SettableMetadata(contentType: 'image/png'));
    final imageUrl = await storageRef.getDownloadURL();

    // 최종 DiaryEntry 반환
    return DiaryEntry(
      id: diaryForAnalysis.id,
      date: diaryForAnalysis.date,
      title: title,
      content: content,
      emotion: emotion,
      aiComment: diaryForAnalysis.aiComment,
      imageUrls: [imageUrl],
      callId: callId,
      analysis: analysis,
    );
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
        "model": "gpt-5.4-mini",
        "messages": promptMessages,
        "max_completion_tokens": 10000,
        "temperature": 0.4,
        "response_format": {"type": "json_object"},
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('분석 생성 실패: ${res.body}');
    }

    final content = jsonDecode(res.body)['choices'][0]['message']['content'];
    final jsonMap = jsonDecode(_stripCodeFence(content));
    return DiaryAnalysis.fromJson(Map<String, dynamic>.from(jsonMap));
  }
}
