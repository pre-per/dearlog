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

/// 통화 시 AI 친구의 기본 시스템 프롬프트(베이스).
///
/// 동적으로 사용자 컨텍스트(닉네임/나잇대/성별/관심사/최근 일기 요약)를 덧붙여서
/// 매 호출마다 [_buildCallSystemPrompt] 를 통해 완성된 프롬프트를 만든다.
///
/// 익명화 정책:
/// - 닉네임만 전달, 실제 이름은 모름.
/// - 정확한 나이 대신 나잇대(예: 20대)만 전달.
/// - 성별은 사용자가 입력한 그대로 (공개 안 함도 그대로 전달).
/// - 이메일·연락처·정확 위치 등 식별정보는 절대 미포함.
/// - 최근 일기는 제목/대표 감정/한 줄 요약만 압축 전달.
const String _callBasePrompt = '''
너는 사용자의 가까운 친구야. 사용자가 전화로 너한테 하루 이야기를 털어놓고 있어.

[캐릭터]
- 따뜻하지만 무겁지 않은 친구. 가끔 농담도 하고 솔직한 말도 하는 편한 사이.
- 너 자신만의 관점, 취향, 일상이 있어. 사용자 이야기에 너의 짧은 감상이나 비슷한 경험을 자연스럽게 곁들여도 돼.
- 사용자가 던진 화제에 너도 같이 빠져들어 이야기를 풀어내. 그냥 듣기만 하는 청자가 아니야.

[형식 규칙]
- 한 응답은 최대 4줄. 보통은 1~2줄이 가장 자연스러워. 짧고 호흡 빠르게.
- 따옴표 절대 쓰지 마. " ' " " ' ' 「 」 『 』 모두 금지.
- 번호 매기기 금지. 1. 2. 3., 첫째/둘째, ① ② ③ 전부 안 돼.
- 글머리 기호 금지. -, *, •, ▪ 같은 거 쓰지 마.
- 마크다운 금지. **굵게**, _기울임_, ~취소선~ 같은 표기 안 돼.
- 이모지는 가끔만. 한 응답에 많아야 한 개. 매 응답마다 쓰지 마.
- 격식체 안 써. 친구처럼 반말로 자연스럽게.
- "~군요", "~네요" 같은 듣기만 하는 어투 반복 금지.

[대화 흐름]
- 매번 질문으로 끝내려 들지 마. 너의 감상, 떠오르는 생각, 짧은 너 얘기로 끝나도 자연스러워.
- 사용자가 화나거나 짜증나는 일을 얘기하면, 같이 공감해주고 가끔은 같이 욕도 해주고 같이 짜증도 내줘. 무조건 위로 모드로 가지 마.
- 사용자가 행복하거나 신난 일을 얘기하면, 너도 같이 신나고 같이 들떠줘.
- 가끔 너의 의견을 솔직하게 말해줘도 돼. 사용자가 잘못 생각하는 것 같으면 친구로서 살짝 짚어줘도 돼.
- "AI", "도우미", "어시스턴트" 같은 단어 쓰지 마. 너는 친구야.
''';

/// 사용자 정보(익명화)와 최근 일기 요약을 베이스 프롬프트에 덧붙여 완성된
/// 시스템 프롬프트를 만든다. profile이 없으면 베이스만 그대로 반환.
String _buildCallSystemPrompt({
  UserProfile? profile,
  List<DiaryEntry> recentDiaries = const [],
}) {
  if (profile == null || !profile.isComplete) {
    return _callBasePrompt;
  }

  final ctx = StringBuffer();
  ctx.writeln();
  ctx.writeln('[사용자 컨텍스트 — 익명화된 정보야. 실제 이름·나이·연락처는 알 수 없어]');
  ctx.writeln('- 닉네임: ${profile.nickname}');
  ctx.writeln('- 나잇대: ${profile.ageGroup}');
  ctx.writeln('- 성별: ${profile.gender}');
  if (profile.interests.isNotEmpty) {
    ctx.writeln('- 관심사: ${profile.interests.join(", ")}');
  }
  ctx.writeln();
  ctx.writeln('이 정보는 사용자가 직접 알려준 거야. "너 20대 남자지?" 같은 식으로 직접 짚지 말고,');
  ctx.writeln('말투·화제·반응의 결을 자연스럽게 맞추는 데에만 활용해. 관심사를 상황에 맞게 슬쩍 곁들이는 정도가 자연스러워.');

  if (recentDiaries.isNotEmpty) {
    ctx.writeln();
    ctx.writeln('[최근 일기 — 며칠 전 너랑 나눴던 이야기들. 자연스럽게 기억하고 있는 척 해도 돼]');
    for (final d in recentDiaries) {
      final date = '${d.date.month}/${d.date.day}';
      final emotion = d.analysis?.emotions.isNotEmpty == true
          ? d.analysis!.emotions.first.name
          : (d.emotion.isNotEmpty ? d.emotion : '잔잔');
      final mood = d.analysis?.moodScore;
      final moodLabel = mood == null ? '' : ' · mood ${mood >= 0 ? "+" : ""}$mood';
      // 본문은 너무 길지 않게 80자만 잘라서 전달.
      final snippet = d.content.replaceAll('\n', ' ').trim();
      final shortSnippet =
          snippet.length > 80 ? '${snippet.substring(0, 80)}…' : snippet;
      ctx.writeln('- $date · ${d.title} · $emotion$moodLabel');
      if (shortSnippet.isNotEmpty) {
        ctx.writeln('  요약: $shortSnippet');
      }
    }
    ctx.writeln();
    ctx.writeln('단, 일기 내용을 그대로 인용하거나 "지난번에 일기에 이런 거 썼지?"라고 직접 짚지 마.');
    ctx.writeln('맥락 정도만 알고 자연스럽게 반응하면 돼.');
  }

  return '$_callBasePrompt$ctx';
}

class OpenAIService {
  final _apiKey = RemoteConfigService().openAIApiKey;

  Future<ChatResponse> getChatResponse(
    List<Message> messages, {
    UserProfile? profile,
    List<DiaryEntry> recentDiaries = const [],
  }) async {
    const url = 'https://api.openai.com/v1/chat/completions';

    final systemPrompt = _buildCallSystemPrompt(
      profile: profile,
      recentDiaries: recentDiaries,
    );

    final allMessages = [
      {
        "role": "system",
        "content": systemPrompt,
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
  Stream<String> streamChatTokens(
    List<Message> messages, {
    UserProfile? profile,
    List<DiaryEntry> recentDiaries = const [],
  }) async* {
    const url = 'https://api.openai.com/v1/chat/completions';

    final systemPrompt = _buildCallSystemPrompt(
      profile: profile,
      recentDiaries: recentDiaries,
    );

    final allMessages = [
      {
        "role": "system",
        "content": systemPrompt,
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

  Future<DiaryEntry> generateDiaryFromMessages(
    List<Message> messages, {
    String? callId,
    void Function(int step)? onStep,
    List<String> existingKeywords = const [],
    bool generateIllustration = true,
  }) async {
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
    final analysis = await generateAnalysisFromDiary(
      diaryForAnalysis,
      existingKeywords: existingKeywords,
    );

    // 3단계: 그림 이미지 생성 — 사용자가 토글로 끄면 스킵.
    // (스킵된 경우 일기 detail에서 나중에 생성 가능. generateIllustrationForDiary 사용.)
    String? imageUrl;
    if (generateIllustration) {
      onStep?.call(3);
      final diaryWithAnalysis = DiaryEntry(
        id: diaryForAnalysis.id,
        date: diaryForAnalysis.date,
        title: title,
        content: content,
        emotion: emotion,
        aiComment: diaryForAnalysis.aiComment,
        imageUrls: const [],
        callId: callId,
        analysis: analysis,
      );
      imageUrl = await generateIllustrationForDiary(diaryWithAnalysis);
    }

    // 최종 DiaryEntry 반환
    return DiaryEntry(
      id: diaryForAnalysis.id,
      date: diaryForAnalysis.date,
      title: title,
      content: content,
      emotion: emotion,
      aiComment: diaryForAnalysis.aiComment,
      imageUrls: imageUrl != null ? [imageUrl] : const [],
      callId: callId,
      analysis: analysis,
    );
  }

  /// 한 달치 일기를 받아 회고 한 단락 + 반복 패턴(1~3개)을 한 번에 생성.
  /// 토큰 절약을 위해 통합 호출. 결과는 [InsightRepository]를 통해 Firestore에 캐시.
  ///
  /// [userName] 이 비어있지 않으면 회고 본문에서 "OO님" 형태로 호명한다.
  Future<MonthlyInsight> generateMonthlyInsight({
    required String monthKey,
    required List<DiaryEntry> diaries,
    String userName = '',
  }) async {
    if (diaries.isEmpty) {
      return MonthlyInsight(
        monthKey: monthKey,
        summary: '아직 이 달의 일기가 없어요.',
        patterns: const [],
        generatedAt: DateTime.now(),
        diaryCount: 0,
      );
    }

    // 일기 요약본을 압축해서 프롬프트로 — 토큰 절약.
    final compactDiaries = diaries.map((d) {
      final analysis = d.analysis;
      final mood = analysis?.moodScore ?? 0;
      final emotion = analysis?.emotions.isNotEmpty == true
          ? analysis!.emotions.first.name
          : d.emotion;
      final nouns = (analysis?.keywords ?? const <KeywordEntry>[])
          .where((k) => k.category == KeywordCategory.noun)
          .map((k) => k.word)
          .take(4)
          .join(', ');
      final dateStr = '${d.date.month}/${d.date.day}';
      return '- $dateStr | mood=$mood | $emotion | $nouns | ${d.title}';
    }).join('\n');

    final hasName = userName.trim().isNotEmpty;
    final nameRule = hasName
        ? '\n- summary 첫 문장 또는 자연스러운 위치에서 한 번만 "$userName님"이라고 호명해. 매 문장마다 부르지 말고 딱 한 번. patterns의 body는 호명 안 해도 됨.'
        : '';

    final messages = [
      {
        "role": "system",
        "content": '''
너는 사용자의 한 달 일기를 따뜻하지만 정확하게 정리하는 회고 작성자야.
아래 일기 요약 데이터를 보고 두 가지를 JSON으로 출력해.

스키마:
{
  "summary": "이번 달의 흐름을 2~3문장으로 묘사한 회고. 따옴표/번호/마크다운 금지.",
  "patterns": [
    {"title":"한 줄 헤드라인", "body":"1~2문장 부연 설명"},
    ... (1~3개)
  ]
}

[summary 규칙]
- 2~3문장. 사용자가 자신을 외부 시점에서 보는 느낌.
- 단순 통계 나열 금지. 흐름과 분위기에 집중.
- 부정·긍정 한쪽으로 치우치지 말고 균형 있게.
- 따옴표("'"), 번호 매기기(1.), 마크다운(**) 절대 사용 금지.
- 부드러운 존댓말("~네요", "~예요", "~이에요")과 친근한 반말 어느 쪽이든 일관되게. 격식체("~입니다")는 피해.$nameRule

[patterns 규칙]
- 1~3개. 데이터에서 보이는 반복 흐름을 "발견" 형태로.
- 각 항목은 specific해야 함. 예: "주말마다 카페가 자주 등장했어요" (○) / "긍정적이에요" (×).
- title: 짧고 구체적인 한 줄.
- body: 1~2문장. 가능하면 mood 평균 같은 수치를 자연스럽게 끼워.
- 데이터가 빈약하면(일기 3개 이하) patterns는 빈 배열도 OK.

JSON 외 텍스트 금지.
'''
      },
      {
        "role": "user",
        "content":
            "[$monthKey 일기 요약 — 총 ${diaries.length}개]\n$compactDiaries"
      }
    ];

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "gpt-5.4-mini",
        "messages": messages,
        "max_completion_tokens": 800,
        "temperature": 0.6,
        "response_format": {"type": "json_object"},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('월간 인사이트 생성 실패: ${response.body}');
    }

    final raw = jsonDecode(response.body)['choices'][0]['message']['content'];
    final json = jsonDecode(_stripCodeFence(raw));

    final summary = (json['summary'] as String? ?? '').trim();
    final patternsRaw = json['patterns'] as List? ?? [];
    final patterns = patternsRaw
        .map((e) => DiscoveredPattern.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.title.trim().isNotEmpty)
        .take(3)
        .toList();

    return MonthlyInsight(
      monthKey: monthKey,
      summary: summary,
      patterns: patterns,
      generatedAt: DateTime.now(),
      diaryCount: diaries.length,
    );
  }

  /// NLP 심리 인사이트 생성.
  /// NLP = 신경언어프로그래밍(Neuro-Linguistic Programming) — 자연어처리 아님.
  /// 일기 텍스트와 [DiaryAnalysis] 를 보고, 사용자가 무의식적으로 사용한
  /// 내재된 동기 / 인지 필터(메타프로그램) 1~3개를 추론한다.
  ///
  /// 분석 페이지의 "오늘의 마음 인지 필터" 카드에서 사용자가 "지금 분석하기" 탭하면
  /// 호출되고, 결과는 [DiaryEntry.nlpInsight] 에 캐시된다.
  Future<NLPInsight> generateNLPInsight({
    required String userName,
    required DiaryEntry diary,
  }) async {
    final analysis = diary.analysis;
    if (analysis == null) {
      throw Exception('분석 데이터가 없어 NLP 인사이트를 만들 수 없어요.');
    }

    final keywordsLine = analysis.keywords
        .map((k) =>
            '${k.word}(${k.category == KeywordCategory.emotion ? "감정어" : "명사"}/감정맥락=${k.emotion})')
        .join(', ');

    final emotionsLine =
        analysis.emotions.map((e) => '${e.name}(${e.score})').join(', ');

    final messages = [
      {
        "role": "system",
        "content": '''
너는 디어로그의 NLP 심리 분석가야.
NLP는 신경언어프로그래밍(Neuro-Linguistic Programming)이라는 심리학 용어로, 자연어처리(Natural Language Processing)와는 완전히 다른 학문이야.
사용자가 일기에 무의식적으로 사용한 언어 패턴 / 사건을 받아들이는 방식 / 의사결정 흐름을 통해, 그 사람의 내재된 동기와 인지 필터(메타프로그램)를 추론한다.

[페르소나]
2030 여성의 마음을 다정하게 비춰주는 따뜻한 NLP 심리 전문가.

[톤 & 매너]
- 부드러운 존댓말. "~네요", "~예요", "~이에요". 격식체 금지.
- 진단/단정/가르침 금지. "데이터를 보니 이런 필터를 쓰고 계시네요"처럼 거울 비춰주는 톤.
- 따옴표 절대 금지(", ', ", ", ', ', 「, 」, 『, 』).
- 번호 매기기 금지(1., 첫째, ① 등).
- 마크다운 금지(**굵게**, _기울임_, # 헤더 등).
- 사용자 호명은 자연스러울 때만 1번 정도. 매번 부르지 마.

[추론 방식 — 자유 태그 생성]
NLP 메타프로그램(인지 필터)은 수십 가지가 있어. 일기에서 가장 두드러지는 1~3개를 자유롭게 추출해.
태그는 미리 정해진 목록이 없어 — 일기 내용에 가장 잘 맞는 이름을 짧게 직접 만들어.

작명 규칙:
- 한국어 명사 + 언더스코어(_) + 방향성 단어 형태 권장.
- 방향성 단어 예시: 지향, 회피, 중심, 방향, 틀, 우선, 성향.
- 길이는 4~7자.
- 같은 일기 안에서 태그가 의미적으로 겹치면 안 됨.

참고할 NLP 메타프로그램 카테고리(이외에도 자유롭게 가능):
- 사람 vs 사물 (예: 사람_지향, 사물_중심)
- 결과 vs 과정 (예: 결과_지향, 과정_중심)
- 접근 vs 회피 동기 (예: 접근_동기, 회피_동기)
- 옵션 vs 절차 (예: 옵션_지향, 절차_지향)
- 큰그림 vs 디테일 (예: 전체_조망, 디테일_집중)
- 유사성 vs 차이성 (예: 유사성_선호, 차이성_민감)
- 내적 vs 외적 준거 (예: 내적_기준, 외적_준거)
- 과거/현재/미래 시간 지향 (예: 과거_회상, 미래_설계)
- 능동 vs 수동 (예: 능동_주도, 환경_반응)

[출력 JSON 스키마]
{
  "filters": [
    {
      "tag": "직접_생성한_태그 (예: 과정_지향)",
      "headline": "한 줄 헤드라인. 8~18자. 태그를 풀어쓴 마음의 모습. 예: 결과보다 과정을 음미하는 마음",
      "body": "2~3문장 본문. 데이터에 근거한 부드러운 거울 비춤. 사용자가 무엇을 잘못했다는 식으로 들리면 안 됨. 왜 이 필터로 보이는지 일기 속 단서를 자연스럽게 녹여서 설명.",
      "evidenceKeywords": ["근거가 된 키워드 1~3개 — 반드시 입력 keywords 안에서만 골라"]
    }
  ]
}

[제약]
1. filters는 1~3개. 데이터 매칭이 모두 약하면 가장 근접한 1개라도 골라.
2. tag는 직접 만들어. 위 카테고리는 참고일 뿐이고 일기에 더 잘 맞는 새 표현이 떠오르면 그걸 써.
3. evidenceKeywords는 반드시 입력 keywords 단어 그대로 사용. 새로 만들지 말 것.
4. body 안에서 따옴표/마크다운/번호 금지.
5. JSON 외 어떤 텍스트도 출력 금지.
'''
      },
      {
        "role": "user",
        "content": '''
[입력 데이터]
사용자 이름: $userName
일기 제목: ${diary.title}
일기 본문:
${diary.content}

대표 감정: $emotionsLine
moodScore: ${analysis.moodScore}
keywords: $keywordsLine
'''
      }
    ];

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "gpt-5.4-mini",
        "messages": messages,
        "max_completion_tokens": 900,
        "temperature": 0.5,
        "response_format": {"type": "json_object"},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('NLP 인사이트 생성 실패: ${response.body}');
    }

    final raw = jsonDecode(response.body)['choices'][0]['message']['content'];
    final json = jsonDecode(_stripCodeFence(raw));

    final filters = (json['filters'] as List? ?? [])
        .map((e) => NLPFilter.fromJson(Map<String, dynamic>.from(e)))
        .where((f) => f.tag.isNotEmpty && f.headline.isNotEmpty)
        .take(3)
        .toList();

    return NLPInsight(
      filters: filters,
      generatedAt: DateTime.now(),
    );
  }

  /// 기존 일기에 대해 그림만 생성 + Storage 업로드 후 다운로드 URL 반환.
  /// 통화 중 그림 생성을 OFF했던 일기를 나중에 그림 추가할 때 사용.
  Future<String> generateIllustrationForDiary(DiaryEntry diary) async {
    final mainWordsStr = (diary.analysis?.keywords ?? const <KeywordEntry>[])
        .where((k) => k.category == KeywordCategory.noun)
        .map((k) => k.word)
        .join(', ');

    final imagePrompt = '''
You are illustrating a single-scene pastel-style diary illustration for a Korean user's daily journal entry.

[DIARY INFO]
- Title: ${diary.title}
- Emotion: ${diary.emotion}
- Key themes: $mainWordsStr
- Content: ${diary.content}

[ILLUSTRATION RULES]
1. Scene: Choose ONE specific location or moment from the content (e.g., a cozy room, a café, a park bench, a bed at night). The scene must directly reflect a concrete detail mentioned in the content — not a generic setting.
2. Character: One small, round, simple cartoon character at the center. The character's pose, action, and facial expression must reflect the emotion ("${diary.emotion}") and what they are doing in the story.
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

    final b64 =
        jsonDecode(imageResponse.body)['data'][0]['b64_json'] as String;
    final imageBytes = base64Decode(b64);
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('diary_images/${DateTime.now().millisecondsSinceEpoch}.png');
    await storageRef.putData(
        imageBytes, SettableMetadata(contentType: 'image/png'));
    return await storageRef.getDownloadURL();
  }
}


extension OpenAIAnalysis on OpenAIService {
  Future<DiaryAnalysis> generateAnalysisFromDiary(
    DiaryEntry diary, {
    List<String> existingKeywords = const [],
  }) async {
    final existingPart = existingKeywords.isEmpty
        ? ''
        : '\n\n[이번 달에 이미 사용된 키워드 목록]\n${existingKeywords.join(", ")}\n\n위 목록에 의미가 유사한 단어가 있으면 반드시 그 단어를 그대로 재사용해라. (예: 목록에 "답답함"이 있으면 "답답한"/"답답해함" 대신 "답답함"으로, "코딩"이 있으면 "코드"/"코드 작성" 대신 "코딩"으로.)';

    final promptMessages = [
      {
        "role": "system",
        "content": '''
너는 감정 분석 리포트 생성기야.
아래 일기 내용을 바탕으로 "오늘의 감정 분석"을 JSON으로만 출력해.

반드시 아래 스키마를 지켜:
{
  "moodScore": -100~100 사이 정수,
  "emotions": [
    {"name":"감정명", "score":0~100},
    ... (1~2개, 통화에서 가장 두드러진 대표 감정)
  ],
  "keywords": [
    {"word":"단어", "category":"emotion"|"noun", "emotion":"이 단어가 등장한 감정 맥락"},
    ... (총 4~5개)
  ],
  "evidence": [
    {"quote":"일기에서 근거 문장 일부", "why":"어떤 감정 근거인지"},
    ... (1~3개)
  ]
}

moodScore 규칙:
- 일기 전반의 종합 기분을 -100 ~ +100 정수로.
- 0 = 평소/중립. 양수 = 긍정 우세, 음수 = 부정 우세.
- 부정 감정(슬픔, 외로움, 우울, 분노, 짜증, 답답함)이 우세하면 음수.
- 긍정 감정(평온, 안정, 차분, 기쁨, 설렘, 즐거움, 행복, 만족, 감사)이 우세하면 양수.
- 강도에 비례. 예: 매우 슬픈 하루 -75, 살짝 짜증 -25, 평범한 하루 0~10, 잔잔한 만족 +30, 큰 기쁨 +75.
- 감정이 섞여있으면 우세한 쪽으로 기울이되 절대값을 낮춰서 표현.

emotions 규칙:
- 1~2개. 일기에서 가장 강하게 드러난 대표 감정.
- name은 반드시 다음 중 하나:
  슬픔, 외로움, 우울, 평온, 안정, 차분, 분노, 짜증, 답답함,
  기쁨, 설렘, 즐거움, 행복, 만족, 감사
- score는 그 감정의 강도(0~100).

keywords 규칙:
- 총 4~5개. 그 중:
  - 1~2개는 category="emotion" — 통화에서 사용자가 표현한 감정 단어 (예: "벅참", "지침", "허무"). emotions 항목과 같아도 되지만 사용자가 실제로 쓴 표현이면 더 좋음.
  - 3개 정도는 category="noun" — 사용자의 하루를 구성한 구체 명사/명사구 (예: "야근", "회사", "엄마", "운동"). 2~6글자.
- '하루','오늘','아침','저녁','시간','일상','보냈다','생각','느낌' 같은 일반어/서술어 금지.
- 모든 키워드의 emotion 필드는 위 emotions name 목록 중 하나로. 그 키워드가 등장했을 때 사용자가 느끼고 있던 감정을 반영.

[형태 표준화 — 매우 중요]
키워드 word는 반드시 다음 형태 규칙을 따른다. 같은 의미가 다른 형태로 분리되면 안 된다.
1. 동사·형용사는 반드시 명사형으로 통일한다:
   - "답답한", "답답했다", "답답해", "답답해함" → "답답함"
   - "지친", "지쳤다", "지쳐있다" → "지침"
   - "벅찼다", "벅찬" → "벅참"
   - "외로웠다", "외로운" → "외로움"
2. 같은 활동/대상은 같은 명사형으로 통일한다:
   - "코드", "코딩한", "코드 작성", "프로그래밍" → "코딩"
   - "운동했다", "운동하기" → "운동"
   - "공부한", "공부했다" → "공부"
3. 어간만 잘라서 만들지 말고, 자연스럽게 읽히는 한국어 명사형을 사용한다.$existingPart

evidence 규칙:
- 1~3개. quote는 일기에서 발췌한 짧은 문장(원문 그대로).
- why는 그 문장이 어떤 감정의 근거인지 한 줄 설명.

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
        "max_completion_tokens": 1500,
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
