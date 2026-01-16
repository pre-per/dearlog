import '../../diary/models/diary_entry.dart';

String buildReminderBody(DiaryEntry? lastDiary, int daysSince) {
  const base = "오늘 하루는 어땠나요? 디어로그에 짧게 기록해볼까요?";

  if (lastDiary?.analysis == null) {
    return daysSince >= 2 ? "오랜만이에요. 오늘 하루를 한 줄만 남겨볼까요?" : base;
  }

  final a = lastDiary!.analysis!;
  final score = a.moodScore;
  final valence = a.valence;
  final risk = a.riskLevel;
  final topEmotion = a.emotions.isNotEmpty ? a.emotions.first.name : null;

  if (risk == "high") {
    return "오늘은 마음을 가볍게 정리해보는 건 어때요? 짧게라도 기록해볼까요?";
  }

  if (valence == "negative" || score <= 35) {
    final emo = topEmotion != null ? " ($topEmotion)" : "";
    return daysSince <= 1
        ? "어제는 기분이 조금 가라앉아 보였어요$emo. 오늘은 좀 어때요? 같이 기록해볼까요?"
        : "최근에 마음이 조금 무거웠을 수도 있어요$emo. 오늘은 어떤 하루였는지 한 줄만 남겨볼까요?";
  }

  if (valence == "positive" || score >= 75) {
    return "이번 주 기분 흐름이 좋아 보여요 😊 오늘도 어떤 하루였는지 기록해볼까요?";
  }

  return daysSince >= 2 ? "며칠만에 기록이네요. 오늘의 기분을 짧게 남겨볼까요?" : base;
}
