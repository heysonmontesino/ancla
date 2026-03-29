import 'package:flutter/material.dart';

// ─── Therapeutic palettes ─────────────────────────────────────────────────────

const Color therapeuticNeutral = Color(0xFF4A4A52);

// Palette A — nature (original)
const List<Color> paletteA = [
  Color(0xFF8BAF92), // sage
  Color(0xFFAA96C8), // lavender
  Color(0xFFD4A89A), // peach
  Color(0xFF8BB4C8), // sky
  Color(0xFF8CC4B0), // mint
  Color(0xFFCCB98A), // sand
];

// Palette B — warm
const List<Color> paletteB = [
  Color(0xFFC8899A), // rose
  Color(0xFFC8A876), // amber
  Color(0xFFC88876), // coral
  Color(0xFFB8A86A), // gold
  Color(0xFFD4A4B0), // blush
  Color(0xFFB89880), // clay
];

// Palette C — cool
const List<Color> paletteC = [
  Color(0xFF7A96B0), // slate
  Color(0xFF8AAAB8), // mist
  Color(0xFF7A8EA0), // steel
  Color(0xFF8890B0), // dusk
  Color(0xFF90A0B0), // fog
  Color(0xFF88B0C0), // ice
];

/// Builds the list of target colors for [count] zones, cycling through [palette].
List<Color> buildZoneTargetColors(int count, List<Color> palette) =>
    List.generate(count, (i) => palette[i % palette.length]);

// ─── Painter ─────────────────────────────────────────────────────────────────

class ColorZonesPainter extends CustomPainter {
  const ColorZonesPainter({
    required this.zoneColors,
    required this.zoneCount,
  });

  final List<Color> zoneColors;
  final int zoneCount;

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < zoneCount; i++) {
      final path = _buildPath(i, size);
      canvas.drawPath(
        path,
        Paint()
          ..color = zoneColors[i]
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(ColorZonesPainter oldDelegate) {
    if (zoneCount != oldDelegate.zoneCount) return true;
    for (int i = 0; i < zoneCount; i++) {
      if (zoneColors[i] != oldDelegate.zoneColors[i]) return true;
    }
    return false;
  }

  /// Returns the index of the topmost zone that contains [point], or -1.
  int findZone(Offset point, Size size) {
    int result = -1;
    for (int i = 0; i < zoneCount; i++) {
      if (_buildPath(i, size).contains(point)) {
        result = i;
      }
    }
    return result;
  }

  // ── Zone path definitions (relative coords scaled to [size]) ─────────────

  Path _buildPath(int index, Size size) {
    final w = size.width;
    final h = size.height;

    switch (index) {
      // ── 8-zone base layout ────────────────────────────────────────────────
      case 0: // top-left blob
        return Path()
          ..moveTo(w * 0.00, h * 0.00)
          ..cubicTo(w * 0.30, h * 0.00, w * 0.54, h * 0.02, w * 0.52, h * 0.16)
          ..cubicTo(w * 0.50, h * 0.28, w * 0.30, h * 0.34, w * 0.18, h * 0.36)
          ..cubicTo(w * 0.08, h * 0.38, w * 0.00, h * 0.32, w * 0.00, h * 0.20)
          ..close();

      case 1: // top-right sweep
        return Path()
          ..moveTo(w * 0.46, h * 0.00)
          ..cubicTo(w * 0.70, h * 0.00, w * 1.00, h * 0.00, w * 1.00, h * 0.00)
          ..cubicTo(w * 1.00, h * 0.18, w * 1.00, h * 0.30, w * 0.80, h * 0.32)
          ..cubicTo(w * 0.62, h * 0.34, w * 0.48, h * 0.22, w * 0.48, h * 0.12)
          ..cubicTo(w * 0.48, h * 0.05, w * 0.48, h * 0.02, w * 0.46, h * 0.00)
          ..close();

      case 2: // left-center blob
        return Path()
          ..moveTo(w * 0.00, h * 0.24)
          ..cubicTo(w * 0.10, h * 0.20, w * 0.32, h * 0.22, w * 0.40, h * 0.32)
          ..cubicTo(w * 0.48, h * 0.42, w * 0.42, h * 0.54, w * 0.28, h * 0.58)
          ..cubicTo(w * 0.14, h * 0.62, w * 0.00, h * 0.54, w * 0.00, h * 0.40)
          ..close();

      case 3: // upper-center cloud
        return Path()
          ..moveTo(w * 0.36, h * 0.10)
          ..cubicTo(w * 0.52, h * 0.06, w * 0.80, h * 0.10, w * 0.84, h * 0.22)
          ..cubicTo(w * 0.88, h * 0.36, w * 0.72, h * 0.46, w * 0.56, h * 0.48)
          ..cubicTo(w * 0.40, h * 0.50, w * 0.28, h * 0.42, w * 0.28, h * 0.28)
          ..cubicTo(w * 0.28, h * 0.18, w * 0.30, h * 0.12, w * 0.36, h * 0.10)
          ..close();

      case 4: // right-center tall
        return Path()
          ..moveTo(w * 0.68, h * 0.28)
          ..cubicTo(w * 0.82, h * 0.24, w * 1.00, h * 0.28, w * 1.00, h * 0.42)
          ..cubicTo(w * 1.00, h * 0.58, w * 0.88, h * 0.66, w * 0.72, h * 0.66)
          ..cubicTo(w * 0.56, h * 0.66, w * 0.52, h * 0.54, w * 0.56, h * 0.42)
          ..cubicTo(w * 0.60, h * 0.32, w * 0.62, h * 0.30, w * 0.68, h * 0.28)
          ..close();

      case 5: // lower-left wide
        return Path()
          ..moveTo(w * 0.00, h * 0.50)
          ..cubicTo(w * 0.16, h * 0.46, w * 0.40, h * 0.50, w * 0.46, h * 0.62)
          ..cubicTo(w * 0.52, h * 0.74, w * 0.38, h * 0.84, w * 0.20, h * 0.86)
          ..cubicTo(w * 0.06, h * 0.88, w * 0.00, h * 0.80, w * 0.00, h * 0.66)
          ..close();

      case 6: // lower-center oval
        return Path()
          ..moveTo(w * 0.28, h * 0.60)
          ..cubicTo(w * 0.46, h * 0.56, w * 0.70, h * 0.58, w * 0.74, h * 0.70)
          ..cubicTo(w * 0.78, h * 0.82, w * 0.60, h * 0.92, w * 0.42, h * 0.94)
          ..cubicTo(w * 0.24, h * 0.96, w * 0.14, h * 0.86, w * 0.18, h * 0.72)
          ..cubicTo(w * 0.22, h * 0.62, w * 0.24, h * 0.62, w * 0.28, h * 0.60)
          ..close();

      case 7: // bottom-right sweep
        return Path()
          ..moveTo(w * 0.60, h * 0.68)
          ..cubicTo(w * 0.76, h * 0.64, w * 1.00, h * 0.66, w * 1.00, h * 0.78)
          ..cubicTo(w * 1.00, h * 0.90, w * 1.00, h * 1.00, w * 0.82, h * 1.00)
          ..cubicTo(w * 0.64, h * 1.00, w * 0.48, h * 0.98, w * 0.48, h * 0.86)
          ..cubicTo(w * 0.48, h * 0.74, w * 0.52, h * 0.70, w * 0.60, h * 0.68)
          ..close();

      // ── 12-zone additions (zones 8–11) ────────────────────────────────────
      case 8: // center fill
        return Path()
          ..moveTo(w * 0.18, h * 0.44)
          ..cubicTo(w * 0.36, h * 0.40, w * 0.58, h * 0.44, w * 0.60, h * 0.58)
          ..cubicTo(w * 0.62, h * 0.70, w * 0.44, h * 0.78, w * 0.24, h * 0.74)
          ..cubicTo(w * 0.06, h * 0.70, w * 0.04, h * 0.58, w * 0.12, h * 0.48)
          ..cubicTo(w * 0.14, h * 0.44, w * 0.16, h * 0.44, w * 0.18, h * 0.44)
          ..close();

      case 9: // bottom-left corner
        return Path()
          ..moveTo(w * 0.00, h * 0.88)
          ..cubicTo(w * 0.16, h * 0.84, w * 0.34, h * 0.86, w * 0.34, h * 0.96)
          ..lineTo(w * 0.34, h * 1.00)
          ..lineTo(w * 0.00, h * 1.00)
          ..close();

      case 10: // right-lower fill
        return Path()
          ..moveTo(w * 0.70, h * 0.56)
          ..cubicTo(w * 0.86, h * 0.52, w * 1.00, h * 0.58, w * 1.00, h * 0.72)
          ..cubicTo(w * 1.00, h * 0.86, w * 0.84, h * 0.92, w * 0.68, h * 0.88)
          ..cubicTo(w * 0.54, h * 0.84, w * 0.52, h * 0.72, w * 0.58, h * 0.62)
          ..cubicTo(w * 0.62, h * 0.56, w * 0.66, h * 0.56, w * 0.70, h * 0.56)
          ..close();

      case 11: // upper-center blob
        return Path()
          ..moveTo(w * 0.18, h * 0.04)
          ..cubicTo(w * 0.36, h * 0.00, w * 0.54, h * 0.00, w * 0.56, h * 0.12)
          ..cubicTo(w * 0.58, h * 0.22, w * 0.44, h * 0.28, w * 0.26, h * 0.26)
          ..cubicTo(w * 0.10, h * 0.24, w * 0.04, h * 0.16, w * 0.10, h * 0.08)
          ..cubicTo(w * 0.12, h * 0.04, w * 0.14, h * 0.04, w * 0.18, h * 0.04)
          ..close();

      // ── 16-zone additions (zones 12–15) ───────────────────────────────────
      case 12: // bottom-center floor
        return Path()
          ..moveTo(w * 0.44, h * 0.80)
          ..cubicTo(w * 0.62, h * 0.76, w * 0.84, h * 0.78, w * 0.86, h * 0.90)
          ..cubicTo(w * 0.88, h * 1.00, w * 0.64, h * 1.00, w * 0.42, h * 1.00)
          ..cubicTo(w * 0.24, h * 1.00, w * 0.20, h * 0.92, w * 0.28, h * 0.84)
          ..cubicTo(w * 0.34, h * 0.78, w * 0.36, h * 0.80, w * 0.44, h * 0.80)
          ..close();

      case 13: // right-upper fill
        return Path()
          ..moveTo(w * 0.68, h * 0.12)
          ..cubicTo(w * 0.84, h * 0.08, w * 1.00, h * 0.12, w * 1.00, h * 0.26)
          ..cubicTo(w * 1.00, h * 0.38, w * 0.86, h * 0.42, w * 0.72, h * 0.38)
          ..cubicTo(w * 0.58, h * 0.34, w * 0.56, h * 0.22, w * 0.62, h * 0.14)
          ..cubicTo(w * 0.64, h * 0.12, w * 0.66, h * 0.12, w * 0.68, h * 0.12)
          ..close();

      case 14: // top-left corner accent
        return Path()
          ..moveTo(w * 0.00, h * 0.00)
          ..cubicTo(w * 0.14, h * 0.00, w * 0.22, h * 0.02, w * 0.20, h * 0.14)
          ..cubicTo(w * 0.18, h * 0.22, w * 0.08, h * 0.24, w * 0.00, h * 0.22)
          ..close();

      case 15: // center hub
        return Path()
          ..moveTo(w * 0.34, h * 0.28)
          ..cubicTo(w * 0.50, h * 0.24, w * 0.68, h * 0.26, w * 0.70, h * 0.38)
          ..cubicTo(w * 0.72, h * 0.50, w * 0.56, h * 0.56, w * 0.38, h * 0.52)
          ..cubicTo(w * 0.22, h * 0.48, w * 0.18, h * 0.38, w * 0.26, h * 0.30)
          ..cubicTo(w * 0.28, h * 0.28, w * 0.30, h * 0.28, w * 0.34, h * 0.28)
          ..close();

      default:
        return Path();
    }
  }
}
