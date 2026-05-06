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
