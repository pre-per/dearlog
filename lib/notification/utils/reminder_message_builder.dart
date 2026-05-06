import '../../diary/models/diary_entry.dart';

const _negativeEmotions = {'슬픔', '외로움', '우울', '분노', '짜증', '답답함'};
const _positiveEmotions = {'평온', '안정', '차분', '기쁨', '설렘', '즐거움', '행복', '만족', '감사'};

String buildReminderBody(DiaryEntry? lastDiary, int daysSince) {
  const base = "오늘 하루는 어땠나요? 디어로그에 짧게 기록해볼까요?";

  if (lastDiary?.analysis == null) {
    return daysSince >= 2 ? "오랜만이에요. 오늘 하루를 한 줄만 남겨볼까요?" : base;
  }

  final a = lastDiary!.analysis!;
  if (a.emotions.isEmpty) {
    return daysSince >= 2 ? "며칠만에 기록이네요. 오늘의 기분을 짧게 남겨볼까요?" : base;
  }

  final top = a.emotions.first;
  final topName = top.name;
  final isNegative = _negativeEmotions.contains(topName);
  final isPositive = _positiveEmotions.contains(topName);
  final intense = top.score >= 70;

  if (isNegative) {
    final emo = " ($topName)";
    return daysSince <= 1
        ? "어제는 마음이 조금 가라앉아 보였어요$emo. 오늘은 좀 어때요? 같이 기록해볼까요?"
        : "최근에 마음이 조금 무거웠을 수도 있어요$emo. 오늘은 어떤 하루였는지 한 줄만 남겨볼까요?";
  }

  if (isPositive && intense) {
    return "최근 기분 흐름이 좋아 보여요 😊 오늘도 어떤 하루였는지 기록해볼까요?";
  }

  return daysSince >= 2 ? "며칠만에 기록이네요. 오늘의 기분을 짧게 남겨볼까요?" : base;
}
