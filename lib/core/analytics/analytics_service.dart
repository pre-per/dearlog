import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// CBT 지표 수집용 얇은 wrapper.
///
/// Firebase가 자동 수집하는 이벤트(별도 호출 불필요):
/// - app_open / session_start / first_open — foreground 진입, 신규 설치, 세션 경계
/// - screen_view — [FirebaseAnalyticsObserver] 가 MaterialApp 의 navigator 에 붙어 있으면
///   Navigator.push/pop 마다 자동 발사. 단, IndexedStack 탭 전환은 안 잡히므로
///   분석 탭 같은 곳은 명시 호출이 필요하다.
///
/// 명시 호출 이벤트:
/// - [logCallStarted] / [logCallEnded] — AI 통화 세션 (= 녹음 길이)
/// - [logReportViewed] — AI 산출물 조회 (일기 상세 / 분석 화면)
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// MaterialApp.navigatorObservers 에 끼우면 push/pop 마다 screen_view 가 자동 기록됨.
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// 로그인 직후 호출 → 같은 사용자의 여러 세션을 GA4 가 묶을 수 있어 리텐션 정확도가 올라간다.
  /// 로그아웃 시 null 로 호출해 분리.
  static Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
    if (kDebugMode) debugPrint('[ANALYTICS] setUserId=$userId');
  }

  /// 인구통계 user property — 성별/연령대.
  /// GA4 대시보드에서 모든 이벤트를 이 두 축으로 segmentation 할 수 있게 한다
  /// (예: "20대 여성의 평균 call_ended.duration_seconds").
  ///
  /// 사전 작업: GA4 콘솔 > Configure > Custom definitions 에 아래 두 개를
  /// "User-scoped" 로 등록해야 모든 reports/explorations 에서 사용 가능.
  ///   - User property name: gender
  ///   - User property name: age_group
  ///
  /// 호출 시점:
  /// - 스플래시/로그인에서 user fetch 직후 (프로필 채워졌을 때)
  /// - 프로필 수정 저장 직후
  /// - 로그아웃 시 [clearUserProperties] 로 청소
  ///
  /// 빈 문자열/null 은 unset 으로 처리해 잘못된 라벨이 GA4 에 박히지 않게 한다.
  static Future<void> setUserProperties({
    String? gender,
    String? ageGroup,
  }) async {
    final g = (gender == null || gender.trim().isEmpty) ? null : gender.trim();
    final a =
        (ageGroup == null || ageGroup.trim().isEmpty) ? null : ageGroup.trim();
    await _analytics.setUserProperty(name: 'gender', value: g);
    await _analytics.setUserProperty(name: 'age_group', value: a);
    if (kDebugMode) {
      debugPrint('[ANALYTICS] setUserProperty gender=$g age_group=$a');
    }
  }

  /// 로그아웃 시 user property 청소. 다음 사용자가 같은 단말에 로그인했을 때
  /// 이전 사용자의 인구통계가 새 세션에 섞이지 않게 한다.
  static Future<void> clearUserProperties() async {
    await _analytics.setUserProperty(name: 'gender', value: null);
    await _analytics.setUserProperty(name: 'age_group', value: null);
    if (kDebugMode) debugPrint('[ANALYTICS] clearUserProperties');
  }

  /// 콜드 스타트 시 main()에서 한 번 호출. Firebase 가 자동 수집하지만 명시 호출로
  /// 누락 가능성을 한 번 더 차단.
  static Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
    if (kDebugMode) debugPrint('[ANALYTICS] app_open');
  }

  /// AI 통화 진입 시점. ([AiChatScreen.initState])
  static Future<void> logCallStarted() async {
    await _analytics.logEvent(name: 'call_started');
    if (kDebugMode) debugPrint('[ANALYTICS] call_started');
  }

  /// AI 통화 종료. (= 녹음 길이 지표)
  /// - [durationSeconds]: 통화 경과 시간 초 단위.
  /// - [messageCount]: 사용자/AI 합산 메시지 개수. 짧은 통화 vs 풍부한 통화 구분에 유용.
  static Future<void> logCallEnded({
    required int durationSeconds,
    required int messageCount,
  }) async {
    await _analytics.logEvent(
      name: 'call_ended',
      parameters: {
        'duration_seconds': durationSeconds,
        'message_count': messageCount,
      },
    );
    if (kDebugMode) {
      debugPrint(
          '[ANALYTICS] call_ended duration=${durationSeconds}s msgs=$messageCount');
    }
  }

  /// AI 산출물 조회.
  /// - [source]: 'diary_detail' (생성된 일기) 또는 'analysis' (감정/월간 인사이트).
  /// - [diaryId]: source=='diary_detail' 일 때만 의미. 어떤 일기를 다시 본 건지 분포 분석용.
  /// - [hasImage]: 그림이 붙은 일기인지. 그림 유무에 따른 재조회 경향 분석용.
  static Future<void> logReportViewed({
    required String source,
    String? diaryId,
    bool? hasImage,
  }) async {
    await _analytics.logEvent(
      name: 'report_viewed',
      parameters: {
        'source': source,
        if (diaryId != null) 'diary_id': diaryId,
        if (hasImage != null) 'has_image': hasImage ? 1 : 0,
      },
    );
    if (kDebugMode) {
      debugPrint(
          '[ANALYTICS] report_viewed source=$source diary=$diaryId hasImage=$hasImage');
    }
  }
}
