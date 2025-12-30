const Map<String, String> planetBaseNameMap = {
  '슬픔': 'blue_moon',
  '외로움': 'blue_moon',
  '우울': 'blue_moon',

  '평온': 'green_moon',
  '안정': 'green_moon',
  '차분': 'green_moon',

  '분노': 'orange_moon',
  '짜증': 'orange_moon',
  '답답함': 'orange_moon',

  '기쁨': 'funny_moon',
  '설렘': 'funny_moon',
  '즐거움': 'funny_moon',

  '행복': 'happy_moon',
  '만족': 'happy_moon',
  '감사': 'happy_moon',
};

String planetAssetForEmotion(String emotion, {bool rounded = false}) {
  final base = planetBaseNameMap[emotion] ?? 'grey_moon';
  if (rounded) {
    return 'asset/image/moon_images/${base}_rounded.png';
  }
  return 'asset/image/moon_images/$base.png';
}
