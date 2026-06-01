/// 일기 그림 생성 시 사용자가 고를 수 있는 시각 스타일.
/// 각 항목은 [promptFragment] 로 OpenAI 이미지 프롬프트에 주입되고,
/// [label] / [description] 은 테마 선택 다이얼로그 UI에 노출된다.
enum IllustrationTheme {
  clay3d(
    label: '3D 찰흙',
    description: '청량한 3D 디오라마, 찰흙 질감과 손글씨',
    promptFragment: '''
Style: Creative 3D isometric miniature diorama.
Floating icons and symbolic objects surround the character,
representing their personality and interests.
[Insert user's favorite keywords here]

Hyper-realistic 3D rendering, Octane render,
Pixar-inspired design, soft studio lighting,
sharp and vibrant colors, shallow depth of field.

Overall atmosphere should feel fresh, bright,
and filled with warm sunlight.

Use elements and composition inspired by the reference feed images.

Transform the entire scene into a handcrafted clay diorama style.
All surrounding icons and decorative objects should also appear
as miniature clay sculptures.

Add natural handwritten notes and doodles on top of the image.
Place white pen-style sketches and Korean handwritten annotations
in the empty spaces around the photo.

The handwritten notes should be short,
casual inner-thought style comments that match the mood.

Use arrows, dotted lines, and subtle outlines
to guide the viewer's attention naturally.

Include small doodles, underlines, stars, and decorative marks,
but keep them tasteful and not excessive.

Place the provided text in the top or bottom margin
using a handwritten style.

Vary the handwriting size and tilt slightly
to create a natural journal-like feeling.

Overall aesthetic should resemble a magazine scrapbook
or personal journal memo style with plenty of breathing space.

Color grading should be warm, vivid, and cheerful.
''',
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
    promptFragment: '''
Style: Children's storybook illustration created with wax crayons.

Render the entire image as a single hand-drawn crayon artwork.

Simplify details and shapes significantly,
as if drawn by a talented 10-year-old child.

Do not preserve the original photo colors.
Instead, use a playful and imaginative color palette.

The drawing should feel like it was created
on clean white paper with visible crayon texture.

Create an extremely cute, warm, and lovable atmosphere.

Add charming childlike elements such as flowers,
hearts, stars, clouds, small animals,
and whimsical decorative doodles.

Emphasize innocence, imagination,
and nostalgic childhood storybook vibes.
''',
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
