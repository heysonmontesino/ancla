import 'package:flutter/material.dart';

import 'constellation_data.dart';

class ConstellationsPainter extends CustomPainter {
  const ConstellationsPainter({
    required this.constellation,
    required this.tapIndex,
    required this.activePulseScale,
    required this.lineReveal,
    required this.backgroundStars,
  });

  final ConstellationData constellation;

  /// How many stars have been tapped so far (0 = none).
  final int tapIndex;

  /// Scale for the currently active (next-to-tap) star: 1.0–1.4–1.0.
  final double activePulseScale;

  /// 0.0→1.0 opacity factor for the most recently drawn line.
  final double lineReveal;

  final List<BackgroundStar> backgroundStars;

  static const double _baseLineOpacity = 0.70;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackgroundStars(canvas, size);
    _drawLines(canvas, size);
    _drawStars(canvas, size);
  }

  void _drawBackgroundStars(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final star in backgroundStars) {
      paint.color = Colors.white.withValues(alpha: star.opacity);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.radius,
        paint,
      );
    }
  }

  void _drawLines(Canvas canvas, Size size) {
    // tapIndex stars tapped → tapIndex-1 lines; the last one is still animating.
    if (tapIndex < 2) return;

    final color = constellation.color;

    for (int i = 0; i < tapIndex - 1; i++) {
      final p1 = Offset(
        constellation.stars[i].dx * size.width,
        constellation.stars[i].dy * size.height,
      );
      final p2 = Offset(
        constellation.stars[i + 1].dx * size.width,
        constellation.stars[i + 1].dy * size.height,
      );

      // All lines except the last are fully revealed; the last animates.
      final double alpha =
          (i < tapIndex - 2) ? _baseLineOpacity : lineReveal * _baseLineOpacity;

      final shader = LinearGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.65),
        ],
      ).createShader(Rect.fromPoints(p1, p2));

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..shader = shader
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawStars(Canvas canvas, Size size) {
    final color = constellation.color;

    for (int i = 0; i < constellation.starCount; i++) {
      final pos = Offset(
        constellation.stars[i].dx * size.width,
        constellation.stars[i].dy * size.height,
      );

      final bool isTapped = i < tapIndex;
      final bool isActive = i == tapIndex;
      final double scale = isActive ? activePulseScale : 1.0;

      // ── Glow halo ────────────────────────────────────────────────────────
      canvas.drawCircle(
        pos,
        14.0 * scale,
        Paint()
          ..color = color.withValues(
            alpha: isTapped ? 0.50 : (isActive ? 0.36 : 0.14),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // ── Colored inner circle ──────────────────────────────────────────────
      canvas.drawCircle(
        pos,
        9.0 * scale,
        Paint()
          ..color = color.withValues(
            alpha: isTapped ? 0.72 : (isActive ? 0.50 : 0.22),
          ),
      );

      // ── White center point ────────────────────────────────────────────────
      canvas.drawCircle(
        pos,
        (isTapped ? 5.0 : (isActive ? 4.0 : 2.5)) * scale,
        Paint()
          ..color = Colors.white.withValues(
            alpha: isTapped ? 0.95 : (isActive ? 0.80 : 0.38),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(ConstellationsPainter oldDelegate) {
    return tapIndex != oldDelegate.tapIndex ||
        activePulseScale != oldDelegate.activePulseScale ||
        lineReveal != oldDelegate.lineReveal ||
        constellation != oldDelegate.constellation;
  }
}
