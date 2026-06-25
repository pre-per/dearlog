import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared_ui/widgets/dialog/glass_dialog.dart';

/// 자살·자해 등 위기 신호 감지 시 전문기관 연락처를 안내한다.
///
/// 일기/감정 대화 성격의 앱이라 위기 상황의 사용자가 있을 수 있는데,
/// 약관의 문구만으로는 실제 위기 시점에 닿지 않는다 — 입력 내용에서
/// 신호가 보이면 그 자리에서 부드럽게 안내한다. 입력 자체를 막지는 않는다.
class CrisisSupport {
  CrisisSupport._();

  /// 공백 제거 후 검사할 위기 신호 패턴. ("각자 해야" → "자해" 같은
  /// 오탐을 피하려고 '자해'는 조사가 붙은 형태만 넣는다)
  static const List<String> _signals = [
    '자살',
    '죽고싶',
    '죽어버리고싶',
    '죽을래',
    '살기싫',
    '살고싶지않',
    '자해를',
    '자해하',
    '자해했',
    '자해충동',
    '손목을긋',
    '손목긋',
    '목숨을끊',
    '극단적선택',
    '극단적인선택',
    '사라지고싶',
  ];

  /// 같은 세션에서 반복 노출로 피로감을 주지 않게 1회만 띄운다.
  static bool _shownThisSession = false;

  static bool containsCrisisSignal(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    return _signals.any(normalized.contains);
  }

  /// [text] 에 위기 신호가 있으면 상담 안내 다이얼로그를 띄운다.
  static Future<void> maybeShowSupport(
    BuildContext context,
    String text,
  ) async {
    if (_shownThisSession) return;
    if (!containsCrisisSignal(text)) return;
    _shownThisSession = true;
    if (!context.mounted) return;

    final call = await showGlassDialog<bool>(
      context: context,
      title: '많이 힘드신가요?',
      message: '혼자 견디기 어려운 마음이 들 때는\n'
          '언제든 전문가의 도움을 받을 수 있어요.\n\n'
          '자살예방 상담전화 109 (24시간 · 무료)\n'
          '정신건강 위기상담 1577-0199\n'
          '청소년 전화 1388',
      actions: const [
        GlassDialogAction(label: '닫기', value: false),
        GlassDialogAction(label: '109 전화하기', value: true, isPrimary: true),
      ],
    );

    if (call == true) {
      try {
        await launchUrl(Uri.parse('tel:109'));
      } catch (_) {/* 통화 불가 기기(iPad 등)에서는 조용히 무시 */}
    }
  }
}
