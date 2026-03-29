import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class TipShareService {
  TipShareService._();

  static Future<void> captureAndShare(GlobalKey key, String tipText) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final BuildContext? currentContext = key.currentContext;
      if (currentContext == null || !currentContext.mounted) {
        throw StateError('No se pudo encontrar la tarjeta para compartir.');
      }

      final RenderObject? renderObject = currentContext.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('La tarjeta no está lista para exportarse.');
      }
      final RenderRepaintBoundary boundary = renderObject;
      final RenderBox? renderBox = currentContext.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);

      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw StateError('No se pudo generar la imagen del consejo.');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final Directory tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/ancla_consejo.png';
      await File(path).writeAsBytes(pngBytes);

      await Share.shareXFiles([
        XFile(path),
      ],
          text: '"$tipText"\n\n— Ancla, tu compañero de calma',
          sharePositionOrigin: sharePositionOrigin);
    } catch (e) {
      if (kDebugMode) debugPrint('[Share] ERROR: $e');
      rethrow;
    }
  }
}
