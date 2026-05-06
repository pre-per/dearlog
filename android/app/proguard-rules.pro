# =====================================================================
# Project ProGuard / R8 keep rules
# =====================================================================
# Flutter 는 release 빌드에서 R8 code shrinking 을 기본 활성화한다.
# R8 이 audio 재생 관련 라이브러리(ExoPlayer/Media3, just_audio,
# audio_session) 의 reflection 기반 내부 코드를 stripping/난독화하면
# 런타임에 "TYPE_UNEXPECTED: null" / "java.lang.NullPointerException at
# <obfuscated>.getName()" 형태로 깨진다. 아래 규칙들로 해당 패키지를
# 보호한다.
# =====================================================================

# ── AndroidX Media3 (ExoPlayer 의 새 이름) ───────────────────────────
# just_audio 0.10+ 은 Media3 1.x 를 사용한다. Media3 자체에도 consumer
# proguard rules 가 들어있지만 일부 reflection 경로가 누락되는 경우가
# 있어서 명시적으로 전체를 보호한다.
-keep class androidx.media3.** { *; }
-keep interface androidx.media3.** { *; }
-dontwarn androidx.media3.**

# ── 구버전 ExoPlayer (com.google.android.exoplayer2.*) ───────────────
# 일부 의존성이 아직 구 패키지 이름을 참조할 수 있음.
-keep class com.google.android.exoplayer2.** { *; }
-keep interface com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# ── just_audio plugin ────────────────────────────────────────────────
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.just_audio.**

# ── audio_session plugin ─────────────────────────────────────────────
-keep class com.ryanheise.audio_session.** { *; }
-dontwarn com.ryanheise.audio_session.**

# ── speech_to_text plugin ────────────────────────────────────────────
# SpeechRecognizer 콜백에 reflection 을 쓰는 경로가 있어 함께 보호.
-keep class com.csdcorp.speech_to_text.** { *; }
-dontwarn com.csdcorp.speech_to_text.**

# ── path_provider / 기타 plugin ──────────────────────────────────────
# path_provider 는 보통 안전하지만 release 에서 가끔 깨지므로 보존.
-keep class io.flutter.plugins.pathprovider.** { *; }

# ── flutter_local_notifications ──────────────────────────────────────
# 알림 탭 콜백 / 예약 알림 BroadcastReceiver / Gson 직렬화에 reflection
# 의존도가 높음. R8 가 잘라내면:
#   - 알림은 표시되지만 탭해도 콜백이 실행 안 됨
#   - zonedSchedule 한 알림이 시간이 돼도 안 옴 (Receiver 가 호출 안 됨)
# 공식 README 에서 권장하는 keep 규칙.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.styles.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Gson (flutter_local_notifications 가 내부적으로 알림 메타데이터 직렬화에 사용)
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn com.google.gson.**

# ── firebase_messaging / Firebase 전반 ───────────────────────────────
# Firebase 는 자체 consumer rules 를 들고 있지만 R8 풀 모드에서
# RemoteMessage 직렬화 / 백그라운드 핸들러 reflection 이 깨지는
# 케이스가 있어 명시적으로 보호.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase 내부에서 참조하는 javax.* 류 (없으면 dontwarn)
-dontwarn javax.annotation.**
-dontwarn javax.lang.model.**

# ── permission_handler ───────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ── flutter_timezone ─────────────────────────────────────────────────
-keep class net.wuerl.flutter_timezone.** { *; }
-dontwarn net.wuerl.flutter_timezone.**

# ── 일반 안전망 ──────────────────────────────────────────────────────
# 어노테이션 보존 (라이브러리들이 런타임에 어노테이션 검사하는 경우).
-keepattributes *Annotation*
# 시그니처 보존 (제네릭 타입 정보 — reflection 시 필요).
-keepattributes Signature
# 내부 클래스 보존 (Media3 내부 enum / sealed class 가 깨지는 케이스 방지).
-keepattributes InnerClasses,EnclosingMethod
# 라인 정보 보존 (운영 중 stack trace 디버깅 용이).
-keepattributes SourceFile,LineNumberTable

# ── BroadcastReceiver / Service 일반 보존 ────────────────────────────
# 예약 알림은 AlarmManager → BroadcastReceiver 경로로 동작함.
# 우리 앱이 직접 정의한 것은 없지만 플러그인이 등록한 Receiver/Service
# 클래스가 R8 에 의해 unused 로 판단되어 잘릴 수 있어 보호.
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
