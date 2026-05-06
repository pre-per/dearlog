import 'dart:ui';

import 'package:flutter/material.dart';

/// 글래스모피즘 다이얼로그.
/// 머티리얼 [AlertDialog] 대체 — 앱 전반의 다크 + 글래스 톤을 유지하기 위함.
///
/// 사용법:
/// ```
/// final ok = await showGlassDialog<bool>(
///   context: context,
///   title: '편지를 삭제할까요?',
///   message: '잠금된 편지가 사라지고 도착 알림도 취소돼요.',
///   actions: [
///     GlassDialogAction(label: '취소', value: false),
///     GlassDialogAction(label: '삭제', value: true, isDestructive: true),
///   ],
/// );
/// ```

class GlassDialogAction<T> {
  final String label;
  final T value;

  /// 빨간 톤 (삭제/위험 액션).
  final bool isDestructive;

  /// 금색 강조 (주요 액션 / 다시 시도 등).
  final bool isPrimary;

  const GlassDialogAction({
    required this.label,
    required this.value,
    this.isDestructive = false,
    this.isPrimary = false,
  });
}

Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<GlassDialogAction<T>> actions,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'dismiss',
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Opacity(
        opacity: curved.value,
        child: Transform.scale(
          scale: 0.94 + (curved.value * 0.06),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) => _GlassDialog<T>(
      title: title,
      message: message,
      actions: actions,
    ),
  );
}

class _GlassDialog<T> extends StatelessWidget {
  final String title;
  final String? message;
  final List<GlassDialogAction<T>> actions;

  const _GlassDialog({
    required this.title,
    this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.13),
                      Colors.white.withOpacity(0.06),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'GowunBatang',
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 13.5,
                              height: 1.6,
                              fontFamily: 'GowunBatang',
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            for (int i = 0; i < actions.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child:
                                    _GlassActionButton<T>(action: actions[i]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 글래스 톤 입력 다이얼로그.
///
/// 한 줄 텍스트 입력 + 취소/확인 두 버튼. 사용자가 확인을 누르면 입력 텍스트를
/// 반환, 취소/배경 탭이면 null. 입력이 비어있으면 확인 버튼 비활성.
///
/// 사용법:
/// ```
/// final result = await showGlassInputDialog(
///   context: context,
///   title: '관심사 직접 추가',
///   hintText: '예: 보드게임',
///   maxLength: 8,
/// );
/// ```
Future<String?> showGlassInputDialog({
  required BuildContext context,
  required String title,
  String? hintText,
  int? maxLength,
  String cancelLabel = '취소',
  String confirmLabel = '추가',
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'dismiss',
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Opacity(
        opacity: curved.value,
        child: Transform.scale(
          scale: 0.94 + (curved.value * 0.06),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) => _GlassInputDialog(
      title: title,
      hintText: hintText,
      maxLength: maxLength,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
    ),
  );
}

class _GlassInputDialog extends StatefulWidget {
  final String title;
  final String? hintText;
  final int? maxLength;
  final String cancelLabel;
  final String confirmLabel;

  const _GlassInputDialog({
    required this.title,
    required this.hintText,
    required this.maxLength,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  @override
  State<_GlassInputDialog> createState() => _GlassInputDialogState();
}

class _GlassInputDialogState extends State<_GlassInputDialog> {
  final _controller = TextEditingController();
  bool _hasText = false;

  static const _gold = Color(0xFFFFD964);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          left: 28,
          right: 28,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.13),
                      Colors.white.withOpacity(0.06),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'GowunBatang',
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controller,
                          autofocus: true,
                          maxLength: widget.maxLength,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          cursorColor: _gold,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'GowunBatang',
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.06),
                            hintText: widget.hintText,
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontFamily: 'GowunBatang',
                            ),
                            counterStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.15)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: _gold, width: 1.4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _GlassActionButton<String?>(
                                action: GlassDialogAction<String?>(
                                  label: widget.cancelLabel,
                                  value: null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _GlassConfirmButton(
                                label: widget.confirmLabel,
                                enabled: _hasText,
                                onTap: _submit,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassConfirmButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _GlassConfirmButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD964);
    final fg = enabled ? gold : Colors.white.withOpacity(0.35);
    final bg = enabled
        ? gold.withOpacity(0.18)
        : Colors.white.withOpacity(0.04);
    final borderColor = enabled
        ? gold.withOpacity(0.42)
        : Colors.white.withOpacity(0.10);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFamily: 'GowunBatang',
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// 작업 진행 중 글래스 다이얼로그.
///
/// `barrierDismissible: false` 로 사용자 입력을 막고, dismiss 는 호출자가
/// 반환된 `dismiss` 함수를 부르거나 직접 `Navigator.of(context, rootNavigator: true).pop()`.
///
/// 사용법:
/// ```
/// final dismiss = showGlassProgressDialog(context: context, message: '회원탈퇴 처리 중...');
/// try { await ...; } finally { dismiss(); }
/// ```
VoidCallback showGlassProgressDialog({
  required BuildContext context,
  required String message,
}) {
  bool dismissed = false;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'progress',
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Opacity(
        opacity: curved.value,
        child: Transform.scale(
          scale: 0.94 + (curved.value * 0.06),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) => PopScope(
      canPop: false, // Android 시스템 백버튼도 막음
      child: _GlassProgressDialog(message: message),
    ),
  );
  return () {
    if (dismissed) return;
    dismissed = true;
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  };
}

class _GlassProgressDialog extends StatelessWidget {
  final String message;
  const _GlassProgressDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.13),
                      Colors.white.withOpacity(0.06),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                // Material 로 감싸지 않으면 Text 에 노란 밑줄(default 디버그 스타일)이
                // 그려짐 — 다이얼로그 본문 밑에 두 줄 밑줄로 보임. transparency 로 통일.
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation(Color(0xFFFFD964)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'GowunBatang',
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassActionButton<T> extends StatelessWidget {
  final GlassDialogAction<T> action;

  const _GlassActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final destructive = action.isDestructive;
    final primary = action.isPrimary;

    final fg = destructive
        ? const Color(0xFFFF7B7B)
        : (primary ? const Color(0xFFFFD964) : Colors.white.withOpacity(0.9));
    final bg = destructive
        ? const Color(0xFFFF7B7B).withOpacity(0.16)
        : (primary
            ? const Color(0xFFFFD964).withOpacity(0.18)
            : Colors.white.withOpacity(0.10));
    final borderColor = destructive
        ? const Color(0xFFFF7B7B).withOpacity(0.42)
        : (primary
            ? const Color(0xFFFFD964).withOpacity(0.42)
            : Colors.white.withOpacity(0.18));

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).pop(action.value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            action.label,
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontWeight: (destructive || primary)
                  ? FontWeight.w800
                  : FontWeight.w700,
              fontFamily: 'GowunBatang',
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
