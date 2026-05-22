/// 일기 그림 생성 시 사용자가 고를 수 있는 시각 스타일.
/// 각 항목은 [promptFragment] 로 OpenAI 이미지 프롬프트에 주입되고,
/// [label] / [description] 은 테마 선택 다이얼로그 UI에 노출된다.
enum IllustrationTheme {
  cozyFairyTale(
    label: '포근한 동화',
    description: '파스텔 손그림, 따뜻한 동화책 분위기',
    promptFragment:
        'Style: Cozy fairy tale storybook illustration. Soft pastel color palette, warm hand-drawn feel, smooth rounded lines with gentle paper-like texture. Whimsical and dreamy atmosphere, soft golden lighting, slightly nostalgic mood — like a page from a beloved children\'s storybook.',
  ),
  japaneseAnime(
    label: '일본 애니메이션',
    description: '지브리·신카이 풍 감성 애니',
    promptFragment:
        'Style: Japanese animation illustration. Studio Ghibli-inspired aesthetic with hints of Makoto Shinkai\'s atmospheric lighting. Detailed yet soft backgrounds, expressive cel-shaded character, vibrant but emotionally restrained colors, crisp clean linework, naturalistic light and atmosphere.',
  ),
  watercolor(
    label: '잔잔한 수채화',
    description: '번진 듯 부드러운 수채 일러스트',
    promptFragment:
        'Style: Delicate watercolor painting. Visible soft brushstrokes, gentle color bleeding and wet-on-wet edges, subtle paper texture, muted yet luminous palette. Calm and ethereal atmosphere with airy negative space, as if painted in a quiet afternoon journal.',
  ),
  crayonStorybook(
    label: '크레용 그림책',
    description: '어린이 그림책 같은 크레용 질감',
    promptFragment:
        'Style: Children\'s crayon drawing in a storybook. Bold simple shapes, visible waxy crayon strokes and textured paper grain, slightly imperfect naive lines, warm primary-leaning palette. Innocent and heartfelt mood — as if drawn from a child\'s own diary.',
  );

  const IllustrationTheme({
    required this.label,
    required this.description,
    required this.promptFragment,
  });

  final String label;
  final String description;
  final String promptFragment;
}
