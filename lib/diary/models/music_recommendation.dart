/// 일기 내용 기반 음악 추천 — 곡 제목 + 아티스트.
/// 클릭하면 "<song> <artist>" 로 유튜브 검색을 띄우는 용도.
class MusicRecommendation {
  final String song;
  final String artist;

  const MusicRecommendation({
    required this.song,
    required this.artist,
  });

  bool get isValid => song.trim().isNotEmpty && artist.trim().isNotEmpty;

  /// 유튜브 검색 URL — 사용자가 친 검색어처럼 보이도록 곡+아티스트만 인코딩.
  String get youtubeSearchUrl {
    final query = Uri.encodeQueryComponent('$song $artist');
    return 'https://www.youtube.com/results?search_query=$query';
  }

  Map<String, dynamic> toJson() => {
        'song': song,
        'artist': artist,
      };

  factory MusicRecommendation.fromJson(Map<String, dynamic> json) {
    return MusicRecommendation(
      song: (json['song'] ?? '') as String,
      artist: (json['artist'] ?? '') as String,
    );
  }
}
