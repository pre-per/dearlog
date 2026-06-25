import 'dart:ui';

import 'package:dearlog/diary/widgets/share/shareable_diary_card.dart';
import 'package:flutter/material.dart';

/// 공유 카드 콘텐츠 토글 + 순서 변경 패널.
///
/// 각 옵션은 글래스 행으로 표시되며, 데이터가 없는 항목은 토글이 비활성된다.
/// 토글 오른쪽의 ↑/↓ 버튼으로 위 / 아래 옵션과 위치를 교환할 수 있다 — 비활성 옵션도
/// 위치를 미리 정해둘 수 있도록 화살표는 토글 상태와 무관하게 동작.
/// 워터마크는 토글 / 순서 대상이 아니므로 여기 노출되지 않는다.
class ShareOptionsPanel extends StatelessWidget {
  final DiaryShareOptions options;
  final ValueChanged<DiaryShareOptions> onChanged;

  /// 그림일기 토글이 가능한지 (그림 URL 보유 여부).
  final bool hasIllustration;

  /// 감정 요약 토글이 가능한지 (analysis 보유 여부).
  final bool hasAnalysis;

  /// NLP 인사이트 토글이 가능한지 (nlpInsight 보유 여부).
  final bool hasNlpInsight;

  const ShareOptionsPanel({
    super.key,
    required this.options,
    required this.onChanged,
    required this.hasIllustration,
    required this.hasAnalysis,
    required this.hasNlpInsight,
  });

  bool _enabledFor(DiaryShareSection s) {
    switch (s) {
      case DiaryShareSection.illustration:
        return hasIllustration;
      case DiaryShareSection.content:
        return true;
      case DiaryShareSection.emotion:
        return hasAnalysis;
      case DiaryShareSection.nlp:
        return hasNlpInsight;
    }
  }

  _SectionMeta _metaFor(DiaryShareSection s, bool currentlyOn) {
    switch (s) {
      case DiaryShareSection.illustration:
        return _SectionMeta(
          icon: Icons.image_outlined,
          title: '그림일기',
          subtitle: hasIllustration
              ? '오늘 만든 그림을 함께 보여줘요'
              : '아직 그림이 없어요. 일기 상세에서 먼저 만들어 주세요',
        );
      case DiaryShareSection.content:
        return _SectionMeta(
          icon: Icons.notes_outlined,
          title: '일기 내용',
          subtitle: currentlyOn
              ? '제목과 본문이 카드에 포함돼요'
              : '제목과 본문은 빠지고 다른 정보만 공유돼요',
        );
      case DiaryShareSection.emotion:
        return _SectionMeta(
          icon: Icons.auto_awesome_outlined,
          title: '오늘의 감정 요약',
          subtitle: hasAnalysis
              ? '주요 감정과 근거 한 줄을 카드에 담아요'
              : '감정 분석 데이터가 아직 없어요',
        );
      case DiaryShareSection.nlp:
        return _SectionMeta(
          icon: Icons.psychology_outlined,
          title: '마음 인지 필터 (NLP)',
          subtitle: hasNlpInsight
              ? '오늘 분석된 인지 필터 1~2개를 보여줘요'
              : '분석 페이지에서 먼저 생성해 주세요',
        );
    }
  }

  void _setInclude(DiaryShareSection s, bool v) {
    switch (s) {
      case DiaryShareSection.illustration:
        onChanged(options.copyWith(includeIllustration: v));
      case DiaryShareSection.content:
        onChanged(options.copyWith(includeContent: v));
      case DiaryShareSection.emotion:
        onChanged(options.copyWith(includeEmotionSummary: v));
      case DiaryShareSection.nlp:
        onChanged(options.copyWith(includeNlpInsight: v));
    }
  }

  void _moveTo(int from, int to) {
    final next = List<DiaryShareSection>.from(options.order);
    final item = next.removeAt(from);
    next.insert(to, item);
    onChanged(options.copyWith(order: next));
  }

  @override
  Widget build(BuildContext context) {
    final order = options.order;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < order.length; i++) ...[
                if (i > 0) const _Divider(),
                _buildRow(order[i], i, order.length),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(DiaryShareSection s, int index, int total) {
    final value = options.include(s);
    final enabled = _enabledFor(s);
    final meta = _metaFor(s, value);
    return _OptionRow(
      key: ValueKey(s),
      icon: meta.icon,
      title: meta.title,
      subtitle: meta.subtitle,
      value: value,
      enabled: enabled,
      canMoveUp: index > 0,
      canMoveDown: index < total - 1,
      onChanged: (v) => _setInclude(s, v),
      onMoveUp: () => _moveTo(index, index - 1),
      onMoveDown: () => _moveTo(index, index + 1),
    );
  }
}

class _SectionMeta {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionMeta({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withOpacity(0.06),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<bool> onChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _OptionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled;
    // 토글 영역(아이콘 + 텍스트 + 스위치)은 disabled 시 흐려지지만,
    // 화살표는 비활성 옵션도 위치 변경이 가능해야 하므로 별도 opacity 유지.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Opacity(
              opacity: disabled ? 0.45 : 1,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: disabled ? null : () => onChanged(!value),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.10)),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white.withOpacity(0.78),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                              fontFamily: 'GowunBatang',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _GlassSwitch(value: value, disabled: disabled),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _ReorderButtons(
            canMoveUp: canMoveUp,
            canMoveDown: canMoveDown,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown,
          ),
        ],
      ),
    );
  }
}

/// 위 / 아래 작은 글래스 화살표 두 개. 토글 오른쪽에 세로로 배치.
class _ReorderButtons extends StatelessWidget {
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _ReorderButtons({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(
          icon: Icons.keyboard_arrow_up,
          enabled: canMoveUp,
          onTap: onMoveUp,
        ),
        const SizedBox(height: 3),
        _ArrowButton(
          icon: Icons.keyboard_arrow_down,
          enabled: canMoveDown,
          onTap: onMoveDown,
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.28,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 30,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ),
    );
  }
}

/// 직접 그린 글래스 톤 스위치 — 머티리얼 Switch 톤을 피해 앱 미감 유지.
class _GlassSwitch extends StatelessWidget {
  final bool value;
  final bool disabled;
  const _GlassSwitch({required this.value, required this.disabled});

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: 40,
      height: 22,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: value
            ? _gold.withOpacity(0.22)
            : Colors.white.withOpacity(0.08),
        border: Border.all(
          color:
              value ? _gold.withOpacity(0.7) : Colors.white.withOpacity(0.18),
        ),
        boxShadow: value && !disabled
            ? [
                BoxShadow(
                  color: _gold.withOpacity(0.25),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? _gold : Colors.white.withOpacity(0.78),
          ),
        ),
      ),
    );
  }
}
