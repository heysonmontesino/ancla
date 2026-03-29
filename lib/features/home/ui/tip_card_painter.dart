import 'dart:math';

import 'package:flutter/material.dart';

enum TipCardStyle { forest, dawn, night }

class TipCardPainter extends CustomPainter {
  TipCardPainter({required this.style});

  final TipCardStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint background = Paint()
      ..shader = _buildGradient(rect).createShader(rect);

    canvas.drawRect(rect, background);

    switch (style) {
      case TipCardStyle.forest:
        _paintForest(canvas, size);
        break;
      case TipCardStyle.dawn:
        _paintDawn(canvas, size);
        break;
      case TipCardStyle.night:
        _paintNight(canvas, size);
        break;
    }
  }

  Gradient _buildGradient(Rect rect) {
    switch (style) {
      case TipCardStyle.forest:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2E1A), Color(0xFF2D4A2D)],
        );
      case TipCardStyle.dawn:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1A2E), Color(0xFF4A2D3A), Color(0xFF6B3D2A)],
          stops: [0.0, 0.58, 1.0],
        );
      case TipCardStyle.night:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0E17), Color(0xFF0B0E17)],
        );
    }
  }

  void _paintForest(Canvas canvas, Size size) {
    final Random random = Random(42);
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int index = 0; index < 8; index++) {
      final double radius =
          size.shortestSide * (0.12 + random.nextDouble() * 0.14);
      final Offset center = Offset(
        size.width * (0.08 + random.nextDouble() * 0.84),
        size.height * (0.08 + random.nextDouble() * 0.84),
      );
      final double opacity = 0.08 + random.nextDouble() * 0.07;
      paint.color = const Color(0xFF8BAF92).withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _paintDawn(Canvas canvas, Size size) {
    final Random random = Random(42);
    final List<Color> palette = const [Color(0xFFB6A3D6), Color(0xFFE2B7A3)];
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int index = 0; index < 5; index++) {
      final double radius =
          size.shortestSide * (0.18 + random.nextDouble() * 0.16);
      final Offset center = Offset(
        size.width * (0.10 + random.nextDouble() * 0.80),
        size.height * (0.12 + random.nextDouble() * 0.76),
      );
      final Color color = palette[index % palette.length].withValues(
        alpha: 0.08 + random.nextDouble() * 0.04,
      );
      paint.color = color;
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _paintNight(Canvas canvas, Size size) {
    final Random random = Random(99);
    final Paint starPaint = Paint()..style = PaintingStyle.fill;

    for (int index = 0; index < 150; index++) {
      final Offset center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final double radius = 0.5 + random.nextDouble();
      starPaint.color = Colors.white.withValues(
        alpha: 0.15 + random.nextDouble() * 0.30,
      );
      starPaint.maskFilter = null;
      canvas.drawCircle(center, radius, starPaint);
    }

    for (int index = 0; index < 3; index++) {
      final Offset center = Offset(
        size.width * (0.18 + random.nextDouble() * 0.64),
        size.height * (0.16 + random.nextDouble() * 0.54),
      );
      final double radius = 1.2 + random.nextDouble() * 0.3;

      starPaint
        ..color = Colors.white.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center, radius * 3.2, starPaint);

      starPaint
        ..color = Colors.white.withValues(alpha: 0.85)
        ..maskFilter = null;
      canvas.drawCircle(center, radius, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TipCardPainter oldDelegate) {
    return oldDelegate.style != style;
  }
}
