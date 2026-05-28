import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/community_share_options.dart';

/// 커뮤니티 공유 시 어떤 정보를 포함할지 토글하는 패널.
///
/// "사진으로 공유" 화면의 옵션 패널과 동일한 글래스 톤. 순서 변경은 없고
/// 토글만 — 게시물 구조는 고정 레이아웃이라 사용자가 정렬할 여지가 없다.
/// 데이터가 없는 항목(예: 이미지가 없는 일기)은 비활성화되어 흐려진다.
class CommunityShareOptionsPanel extends StatelessWidget {
  final CommunityShareOptions options;
  final ValueChanged<CommunityShareOptions> onChanged;

  final bool hasImages;
  final bool hasEmotion;
  final bool hasNlpInsight;

  const CommunityShareOptionsPanel({
    super.key,
    required this.options,
    required this.onChanged,
    required this.hasImages,
    required this.hasEmotion,
    required this.hasNlpInsight,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <_OptionMeta>[
      _OptionMeta(
        icon: Icons.image_outlined,
        title: '그림일기',
        subtitle: hasImages
            ? '카드와 함께 일기 그림을 보여줘요'
            : '이 일기에 그림이 없어요',
        enabled: hasImages,
        value: options.includeImages && hasImages,
        onChanged: (v) => onChanged(options.copyWith(includeImages: v)),
      ),
      _OptionMeta(
        icon: Icons.title_outlined,
        title: '제목',
        subtitle: '게시물 상단에 제목을 보여줘요',
        enabled: true,
        value: options.includeTitle,
        onChanged: (v) => onChanged(options.copyWith(includeTitle: v)),
      ),
      _OptionMeta(
        icon: Icons.notes_outlined,
        title: '본문',
        subtitle: '일기 본문을 게시물에 포함해요',
        enabled: true,
        value: options.includeContent,
        onChanged: (v) => onChanged(options.copyWith(includeContent: v)),
      ),
      _OptionMeta(
        // 토글 아이콘과 게시물 헤더의 행성 아이콘이 시각적으로 일치해야 사용자가
        // "이게 그 행성 토글이구나" 를 즉시 알아챈다. (이전에는 AI 별 아이콘을
        // 썼는데, AI 분석 토글로 오해되는 문제가 있었다.)
        assetPath: 'asset/image/moon_images/grey_moon.png',
        title: '오늘의 감정',
        subtitle: hasEmotion
            ? '게시물 헤더의 행성 아이콘으로 감정을 보여줘요'
            : '감정 데이터가 없어요',
        enabled: hasEmotion,
        value: options.includeEmotion && hasEmotion,
        onChanged: (v) => onChanged(options.copyWith(includeEmotion: v)),
      ),
      _OptionMeta(
        icon: Icons.calendar_today_outlined,
        title: '일기 작성 날짜',
        subtitle: '"yyyy.MM.dd 작성" 으로 일기 본래 날짜를 표시해요',
        enabled: true,
        value: options.includeDate,
        onChanged: (v) => onChanged(options.copyWith(includeDate: v)),
      ),
      _OptionMeta(
        icon: Icons.psychology_outlined,
        title: '마음 인지 필터 (NLP)',
        subtitle: hasNlpInsight
            ? '본문과 분리된 별도 블록으로 인지 필터를 보여줘요'
            : '분석 페이지에서 먼저 생성해 주세요',
        enabled: hasNlpInsight,
        value: options.includeNlpInsight && hasNlpInsight,
        onChanged: (v) => onChanged(options.copyWith(includeNlpInsight: v)),
      ),
    ];

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
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const _Divider(),
                _OptionRow(meta: rows[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 한 토글 항목의 메타. 아이콘은 [icon] (Material) 또는 [assetPath] (이미지)
/// 중 하나로 표현 — 감정 항목처럼 게시물 자체에 행성 이미지가 들어가는 경우는
/// 토글 옆 미리보기도 같은 이미지로 통일하기 위해 image 경로를 받는다.
class _OptionMeta {
  final IconData? icon;
  final String? assetPath;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _OptionMeta({
    this.icon,
    this.assetPath,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.value,
    required this.onChanged,
  }) : assert(icon != null || assetPath != null,
            'icon 이나 assetPath 둘 중 하나는 있어야 한다');
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
  final _OptionMeta meta;
  const _OptionRow({required this.meta});

  @override
  Widget build(BuildContext context) {
    final disabled = !meta.enabled;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: disabled ? null : () => meta.onChanged(!meta.value),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                alignment: Alignment.center,
                child: meta.assetPath != null
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(
                          meta.assetPath!,
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Icon(
                        meta.icon,
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
                      meta.title,
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
                      meta.subtitle,
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
              _GlassSwitch(value: meta.value, disabled: disabled),
            ],
          ),
        ),
      ),
    );
  }
}

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
