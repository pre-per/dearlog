/// 일기 그림 생성 시 사용자가 고를 수 있는 시각 스타일.
/// 각 항목은 [promptFragment] 로 OpenAI 이미지 프롬프트에 주입되고,
/// [label] / [description] 은 테마 선택 다이얼로그 UI에 노출된다.
///
/// [promptFragment] 는 공통 프롬프트(openai_service.dart)의 "스타일" 슬롯에만
/// 들어간다. 장면 선택 / 캐릭터 / 핵심 사물 / 구도 / "텍스트 금지" 는 공통
/// 프롬프트가 이미 지시하므로, 여기서는 화풍 고유의 질감·색감·선·무드만 다룬다.
enum IllustrationTheme {
  pastelDiary(
    label: '파스텔 그림일기',
    description: '핀터레스트 감성 파스텔 손그림',
    promptFragment: '''
Style: Refined Korean lifestyle diary illustration with delicate colored-pencil linework,
subtle transparent pastel pigment, and a soft matte paper texture.

The image should feel like a personal editorial illustration:
quiet, polished, intimate, and naturally beautiful rather than overly cute.

Use gentle muted colors such as:
warm cream, pale sky blue, dusty pink, sage green,
soft apricot, faded beige, muted yellow, and soft brown.

Use light airy shading and restrained detail.
Add slightly more detail around the main focal point,
while keeping the rest of the image calm and uncluttered.

Characters should have natural, mature proportions with simple but believable facial features.
The image may include an adult figure, a couple, friends,
or a family scene when the diary requires it.

Think of a calm Korean stationery illustration,
a soft Pinterest lifestyle drawing,
or a contemporary journal cover:
elegant, warm, hand-drawn, emotionally observant, and quietly nostalgic.

Avoid:
- chibi proportions
- childish crayon texture
- exaggerated blush
- big anime eyes
- flat vector art
- glossy digital rendering
- crowded details
- stickers
- doodles
- decorative icons
- childish picture book styling
''',
  ),

  retroAnime(
    label: '레트로 애니메이션',
    description: '잔잔한 8090 셀 애니메이션',
    promptFragment: '''
Style: A quiet cinematic still from a hand-painted 1980s to 1990s cel animation.

Use clean hand-drawn outlines, soft flat cel colors,
and a richly observed painted background.

The image should feel like an intimate slice-of-life film frame:
a warm restaurant by the sea,
a calm evening street,
a peaceful family dinner,
a quiet café,
a bedroom at dusk,
or a memorable travel scene.

Use restrained natural facial expressions and realistic human proportions.
Frame the image like a film still with deliberate composition,
atmospheric depth, and a strong sense of time and place.

Use muted navy, amber, olive, dusty rose,
warm brown, faded blue, and soft gray tones.

Lighting may be:
- warm indoor light
- cloudy daylight
- gentle sunset
- quiet evening light

But it should never look overly dramatic, glossy, neon, or artificial.

Avoid:
- chibi characters
- modern glossy anime
- oversized eyes
- webtoon style
- 3D rendering
- photorealism
- neon lighting
- lens flare
- fantasy effects
- exaggerated sentimental sunset glow
''',
  ),

  watercolor(
    label: '잔잔한 수채화',
    description: '번진 듯 부드러운 수채 일러스트',
    promptFragment: '''
Style: A delicate editorial watercolor illustration on softly textured off-white paper.

Use transparent watercolor washes,
gentle pigment bleeding,
subtle brush marks,
soft wet-on-wet edges,
and selective colored-pencil details.

Keep the composition refined and clear.
The image should feel airy, mature, and quietly emotional,
like an illustrated travel journal or a personal memory painted after a calm afternoon.

Use a restrained luminous palette with soft natural colors.
Keep the scene elegant and observational rather than cute, childish, or storybook-like.

Use people sparingly and naturally.
When people appear, maintain believable mature proportions
and calm understated expressions.

Avoid:
- anime styling
- chibi characters
- heavy black outlines
- thick paint
- bright saturated colors
- collage layouts
- decorative doodles
- fantasy effects
- overly polished digital watercolor
- generic cute cartoon styling
''',
  ),

  crayonDiary(
    label: '크레용 그림일기',
    description: '아이가 그린 듯한 크레용 손그림',
    promptFragment: '''
Style: A warm hand-drawn wax crayon diary illustration on off-white paper.

Use visible crayon grain,
imperfect hand-drawn outlines,
simple shapes,
uneven coloring,
and a limited cheerful color palette.

The scene must still portray ONE coherent moment from the diary,
not a random sticker sheet or a page filled with unrelated doodles.

Keep the illustration simple and handmade.
Use only one to three small supporting doodles,
and only when they are directly connected to the story.

When adults appear,
draw them with simplified but age-appropriate proportions.
Do not automatically turn every diary author into a young child.

The final image should feel like a sincere,
slightly clumsy personal drawing:
sweet, nostalgic, expressive, and easy to understand.

Avoid:
- polished anime
- realistic rendering
- glossy digital art
- crowded objects
- exaggerated mascot faces
- giant heads
- random hearts and stars
- full-page collage compositions
- unrelated decorative elements
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
