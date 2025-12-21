import 'package:flutter_riverpod/flutter_riverpod.dart';

final faqProvider = Provider<List<Map<String, String>>>((ref) {
  return [
    {
      "question": "AI 일기는 어떻게 감정을 분석하나요?",
      "answer": "사용자가 작성한 문장을 기반으로 자연어 처리 기술을 통해 감정 상태를 분석합니다. 감정은 긍정, 중립, 부정 등으로 분류되며, 분석 결과는 일기 하단에서 확인할 수 있습니다."
    },
    {
      "question": "일기 내용은 다른 사람과 공유되나요?",
      "answer": "아니요, 작성하신 일기는 본인만 볼 수 있으며, 서버에 암호화되어 안전하게 저장됩니다. 공유 기능을 직접 활성화하지 않는 이상 외부로 노출되지 않습니다."
    },
    {
      "question": "AI가 일기 내용을 추천해주기도 하나요?",
      "answer": "글감이 떠오르지 않을 때, AI가 오늘 하루 있었던 일이나 감정을 정리할 수 있도록 문장과 질문을 제안해줍니다. 언제든 추천 버튼을 눌러 활용해보세요!"
    },
  ];
});
