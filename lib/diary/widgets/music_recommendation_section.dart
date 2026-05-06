import 'package:dearlog/app.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 일기 분위기에 맞는 음악 추천 섹션.
///
/// 상태 4가지:
/// - 추천 있음: 곡/아티스트 카드 → 탭하면 유튜브 검색 페이지로 이동.
/// - 로딩 중: 스피너 + 안내 문구.
/// - 에러: 안내 문구 + 다시 시도 버튼.
/// - 추천 없음(기존 일기): "음악 추천 받기" CTA 버튼.
///
/// 신규 일기는 통화 종료 시 자동 생성되어 [DiaryEntry.music] 에 저장돼 있고,
/// 기존 일기는 사용자가 버튼을 눌러야 생성된다.
class MusicRecommendationSection extends ConsumerStatefulWidget {
  final DiaryEntry diary;
  final Future<void> Function(DiaryEntry) onUpdate;

  const MusicRecommendationSection({
    super.key,
    required this.diary,
    required this.onUpdate,
  });

  @override
  ConsumerState<MusicRecommendationSection> createState() =>
      _MusicRecommendationSectionState();
}

class _MusicRecommendationSectionState
    extends ConsumerState<MusicRecommendationSection> {
  static const _gold = Color(0xFFFFD964);

  bool _loading = false;
  String? _error;

  Future<void> _fetch() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final music =
          await OpenAIService().generateMusicRecommendation(widget.diary);
      final updated = widget.diary.copyWith(music: music);
      await widget.onUpdate(updated);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _openYoutube(MusicRecommendation music) async {
    final uri = Uri.parse(music.youtubeSearchUrl);
    try {
      final ok =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('유튜브를 열 수 없어요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('유튜브 연결 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _gold.withOpacity(0.16),
            border: Border.all(color: _gold.withOpacity(0.40)),
          ),
          child: const Icon(Icons.music_note, color: _gold, size: 16),
        ),
        const SizedBox(width: 10),
        const Text(
          '오늘의 음악',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            fontFamily: 'GowunBatang',
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final music = widget.diary.music;
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();
    if (music != null && music.isValid) return _buildMusic(music);
    return _buildIdle();
  }

  Widget _buildMusic(MusicRecommendation music) {
    return GestureDetector(
      onTap: () => _openYoutube(music),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _gold.withOpacity(0.55),
                    _gold.withOpacity(0.20),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withOpacity(0.30),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.headphones,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    music.song,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'GowunBatang',
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    music.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontSize: 12.5,
                      fontFamily: 'GowunBatang',
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _gold.withOpacity(0.40)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: _gold, size: 14),
                  SizedBox(width: 2),
                  Text(
                    '듣기',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_gold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '일기에 어울리는 노래를 고르고 있어요...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'GowunBatang',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline,
                  color: Colors.redAccent.withOpacity(0.85), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '음악 추천을 가져오지 못했어요',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'GowunBatang',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _fetch,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _gold.withOpacity(0.45)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: _gold, size: 14),
                    SizedBox(width: 5),
                    Text(
                      '다시 시도',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'GowunBatang',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '이 일기에 어울리는 노래를 추천 받아볼까요?',
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 12.5,
            height: 1.45,
            fontFamily: 'GowunBatang',
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _fetch,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _gold.withOpacity(0.50)),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withOpacity(0.18),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_note, color: _gold, size: 14),
                  SizedBox(width: 6),
                  Text(
                    '음악 추천 받기',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'GowunBatang',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
