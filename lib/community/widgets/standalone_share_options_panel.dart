import 'dart:ui';

import 'package:flutter/material.dart';

/// 일기 없이 직접 작성하거나 기존 게시글을 수정할 때 사용하는 토글 옵션.
///
/// 일기 공유의 [CommunityShareOptions] 와 달리 그림·작성일·NLP 같은 일기 종속
/// 항목이 빠지고, 게시 후에도 수정 가능한 제목·본문·감정 세 가지만 다룬다.
/// 토글 OFF 면 해당 입력 섹션이 화면에서 사라지고 빈 값으로 저장된다.
class StandaloneShareOptions {
  final bool includeTitle;
  final bool includeContent;
  final bool includeEmotion;

  const StandaloneShareOptions({
    required this.includeTitle,
    required this.includeContent,
    required this.includeEmotion,
  });

  /// 진입 시 초기값. 제목·본문 입력 칸은 늘 노출(사용자가 비어있을 때 채울 수
  /// 있어야 함), 감정은 기존에 설정돼 있던 경우에만 ON.
  factory StandaloneShareOptions.initial({required bool hasEmotion}) {
    return StandaloneShareOptions(
      includeTitle: true,
      includeContent: true,
      includeEmotion: hasEmotion,
    );
  }

  StandaloneShareOptions copyWith({
    bool? includeTitle,
    bool? includeContent,
    bool? includeEmotion,
  }) {
    return StandaloneShareOptions(
      includeTitle: includeTitle ?? this.includeTitle,
      includeContent: includeContent ?? this.includeContent,
      includeEmotion: includeEmotion ?? this.includeEmotion,
    );
  }
}

/// 제목/본문/감정 3개 토글 패널. 일기 공유 패널과 글래스 톤을 통일.
class StandaloneShareOptionsPanel extends StatelessWidget {
  final StandaloneShareOptions options;
  final ValueChanged<StandaloneShareOptions> onChanged;

  const StandaloneShareOptionsPanel({
    super.key,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <_RowMeta>[
      _RowMeta(
        icon: Icons.title_outlined,
        title: '제목',
        subtitle: '게시물 상단에 제목을 보여줘요',
        value: options.includeTitle,
        onChanged: (v) => onChanged(options.copyWith(includeTitle: v)),
      ),
      _RowMeta(
        icon: Icons.notes_outlined,
        title: '본문',
        subtitle: '본문을 게시물에 포함해요',
        value: options.includeContent,
        onChanged: (v) => onChanged(options.copyWith(includeContent: v)),
      ),
      _RowMeta(
        assetPath: 'asset/image/moon_images/grey_moon.png',
        title: '오늘의 감정',
        subtitle: '게시물 헤더의 행성 아이콘으로 감정을 보여줘요',
        value: options.includeEmotion,
        onChanged: (v) => onChanged(options.copyWith(includeEmotion: v)),
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
                if (i > 0)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.white.withOpacity(0.06),
                  ),
                _Row(meta: rows[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RowMeta {
  final IconData? icon;
  final String? assetPath;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _RowMeta({
    this.icon,
    this.assetPath,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  }) : assert(icon != null || assetPath != null);
}

class _Row extends StatelessWidget {
  final _RowMeta meta;
  const _Row({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => meta.onChanged(!meta.value),
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
            _GlassSwitch(value: meta.value),
          ],
        ),
      ),
    );
  }
}

class _GlassSwitch extends StatelessWidget {
  final bool value;
  const _GlassSwitch({required this.value});

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
        boxShadow: value
            ? [BoxShadow(color: _gold.withOpacity(0.25), blurRadius: 10)]
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
