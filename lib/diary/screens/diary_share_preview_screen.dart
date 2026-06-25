import 'dart:ui';

import 'package:dearlog/app.dart';
import 'package:dearlog/diary/services/diary_image_exporter.dart';
import 'package:dearlog/diary/widgets/share/share_options_panel.dart';
import 'package:dearlog/diary/widgets/share/shareable_diary_card.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

/// 오늘의 일기를 사진으로 사진 앱(갤러리)에 저장하기 위한 프리뷰 화면.
///
/// 9:16 스토리형 카드 미리보기 + 콘텐츠 토글 패널 + 저장 버튼.
class DiarySharePreviewScreen extends StatefulWidget {
  final DiaryEntry diary;

  const DiarySharePreviewScreen({super.key, required this.diary});

  @override
  State<DiarySharePreviewScreen> createState() =>
      _DiarySharePreviewScreenState();
}

class _DiarySharePreviewScreenState extends State<DiarySharePreviewScreen> {
  final GlobalKey _cardBoundaryKey = GlobalKey();
  late DiaryShareOptions _options;
  bool _saving = false;
  bool _illustrationPrecached = false;

  @override
  void initState() {
    super.initState();
    _options = DiaryShareOptions.initialFor(widget.diary);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 캡쳐 시점에 network 이미지가 빈 상태로 잡히지 않도록 진입과 동시에 캐시 로드.
    if (!_illustrationPrecached && widget.diary.imageUrls.isNotEmpty) {
      _illustrationPrecached = true;
      // 실패해도 카드는 errorBuilder 로 안전.
      // ignore: unawaited_futures
      precacheImage(
        NetworkImage(widget.diary.imageUrls.first),
        context,
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // 옵션 변경 직후 탭하면 layout 이 갱신되기 전일 수 있어 한 프레임 양보.
      await WidgetsBinding.instance.endOfFrame;

      await DiaryImageExporter.saveCardToGallery(
        boundaryKey: _cardBoundaryKey,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진 앱에 저장했어요'),
          backgroundColor: Color(0xFF1E1E2E),
          duration: Duration(seconds: 2),
        ),
      );
    } on GalException catch (e) {
      if (!mounted) return;
      // 권한 거부 등 사용자가 다시 시도해야 하는 케이스는 메시지 분기.
      final message = e.type == GalExceptionType.accessDenied
          ? '사진 접근 권한이 없어요. 설정에서 허용해 주세요'
          : '저장에 실패했어요';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF1E1E2E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장에 실패했어요: $e'),
          backgroundColor: const Color(0xFF1E1E2E),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diary = widget.diary;
    return BaseScaffold(
      appBar: AppBar(
        title: const Text(
          '사진 앱에 저장',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'GowunBatang',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 카드 미리보기 — RepaintBoundary 안쪽이 캡쳐 영역.
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  child: RepaintBoundary(
                    key: _cardBoundaryKey,
                    child: ShareableDiaryCard(
                      diary: diary,
                      options: _options,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _PreviewHint(),
              const SizedBox(height: 16),
              ShareOptionsPanel(
                options: _options,
                onChanged: (next) => setState(() => _options = next),
                hasIllustration: diary.imageUrls.isNotEmpty,
                hasAnalysis: diary.analysis != null,
                hasNlpInsight: diary.nlpInsight != null,
              ),
              const SizedBox(height: 22),
              _SaveActionButton(
                saving: _saving,
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          IconsaxPlusLinear.info_circle,
          size: 13,
          color: Colors.white.withOpacity(0.4),
        ),
        const SizedBox(width: 6),
        Text(
          '아래 옵션을 바꾸면 미리보기가 즉시 갱신돼요',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SaveActionButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onTap;
  const _SaveActionButton({required this.saving, required this.onTap});

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: _gold.withOpacity(0.16),
              border: Border.all(color: _gold.withOpacity(0.55)),
              boxShadow: [
                BoxShadow(
                  color: _gold.withOpacity(0.22),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (saving)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(_gold),
                    ),
                  )
                else
                  const Icon(
                    IconsaxPlusLinear.gallery_add,
                    color: _gold,
                    size: 18,
                  ),
                const SizedBox(width: 8),
                Text(
                  saving ? '이미지 저장 중' : '사진 앱에 저장',
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'GowunBatang',
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
