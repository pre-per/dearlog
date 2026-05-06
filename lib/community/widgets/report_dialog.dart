import 'dart:ui';
import 'package:flutter/material.dart';

/// 미리 정의된 신고 사유. 라벨은 사용자에게 보이는 한국어, value 는
/// Firestore 에 저장되는 안정 식별자.
const List<({String value, String label})> reportReasons = [
  (value: 'inappropriate', label: '부적절한 내용 (욕설·음란)'),
  (value: 'spam', label: '스팸 또는 광고'),
  (value: 'violence', label: '폭력적이거나 위험한 내용'),
  (value: 'privacy', label: '개인정보 노출 또는 사칭'),
  (value: 'other', label: '기타'),
];

/// 신고 사유를 선택받아 라벨을 반환하는 글래스 다이얼로그.
/// 취소 시 null. "기타" 선택 시 라벨 그대로 저장.
Future<String?> showReportReasonDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (_) => const _ReportDialog(),
  );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _selected;
  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '신고 사유를 선택해 주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'GowunBatang',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '운영자가 검토 후 적절한 조치를 취해요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                    fontFamily: 'GowunBatang',
                  ),
                ),
                const SizedBox(height: 18),
                for (final r in reportReasons) ...[
                  _ReasonRow(
                    label: r.label,
                    selected: _selected == r.value,
                    onTap: () => setState(() => _selected = r.value),
                  ),
                  if (r != reportReasons.last) const SizedBox(height: 6),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _DialogAction(
                        label: '취소',
                        onTap: () => Navigator.of(context).pop(null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DialogAction(
                        label: '신고하기',
                        accent: _gold,
                        onTap: _selected == null
                            ? null
                            : () {
                                final r = reportReasons.firstWhere(
                                  (x) => x.value == _selected,
                                );
                                Navigator.of(context).pop(r.label);
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? _gold.withOpacity(0.14)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _gold : Colors.white.withOpacity(0.10),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected ? _gold : Colors.white.withOpacity(0.45),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _gold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withOpacity(0.85),
                  fontSize: 13.5,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  fontFamily: 'GowunBatang',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogAction extends StatelessWidget {
  final String label;
  final Color? accent;
  final VoidCallback? onTap;
  const _DialogAction({
    required this.label,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final color = accent ?? Colors.white.withOpacity(0.85);

    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: accent != null
                ? accent!.withOpacity(0.16)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent != null
                  ? accent!.withOpacity(0.5)
                  : Colors.white.withOpacity(0.15),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFamily: 'GowunBatang',
            ),
          ),
        ),
      ),
    );
  }
}
