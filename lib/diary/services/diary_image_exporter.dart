import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';

/// 일기 공유 카드(9:16 RepaintBoundary)를 PNG로 변환해 사진 앱(갤러리)에 저장.
///
/// 흐름: RepaintBoundary GlobalKey → ui.Image → PNG bytes → Gal.putImageBytes.
class DiaryImageExporter {
  DiaryImageExporter._();

  /// [boundaryKey] : 9:16 카드를 감싼 RepaintBoundary 의 GlobalKey.
  /// [pixelRatio]  : 3.0 이면 화면 표시 크기 ×3 해상도로 캡쳐 (예: 390×693 → 1170×2080).
  ///
  /// 저장 권한이 거부되면 [GalException] 이 던져진다 — 호출부에서 사용자에게 안내.
  static Future<void> saveCardToGallery({
    required GlobalKey boundaryKey,
    double pixelRatio = 3.0,
  }) async {
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('저장할 카드를 찾지 못했어요');
    }
    // 이미지/폰트가 같은 프레임에서 아직 paint 되지 않았으면 한 프레임 더 기다린다.
    await WidgetsBinding.instance.endOfFrame;

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('이미지를 생성하지 못했어요');
    }
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    // toAlbum:false 면 add-only 권한 (NSPhotoLibraryAddUsageDescription) 만으로
    // 동작. true 로 두면 iOS 가 read 권한 (NSPhotoLibraryUsageDescription) 도
    // 요구해 키가 없으면 앱이 SIGABRT 로 강제 종료된다.
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      await Gal.requestAccess();
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    await Gal.putImageBytes(
      pngBytes,
      name: 'dearlog_$stamp',
    );
  }
}
