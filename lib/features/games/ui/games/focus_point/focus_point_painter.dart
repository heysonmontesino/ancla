import 'package:flutter/material.dart';

class FocusPointPainter extends CustomPainter {
  const FocusPointPainter({
    required this.position,
    required this.trail,
    required this.pulseScale,
    required this.pointColor,
  });

  /// Current center of the focus point.
  final Offset position;

  /// Last N positions (oldest first, newest last).
  final List<Offset> trail;

  /// Scale multiplier applied to the main circle (1.0 = normal, 1.2 = pulsed).
  final double pulseScale;

  /// Current color of the point (animates between palette entries).
  final Color pointColor;

  static const double _pointRadius = 28.0;
  static const int _trailLength = 12;

  @override
  void paint(Canvas canvas, Size size) {
    _drawTrail(canvas);
    _drawGlow(canvas);
    _drawPoint(canvas);
  }

  void _drawTrail(Canvas canvas) {
    final int count = trail.length;
    for (int i = 0; i < count; i++) {
      final double progress = (i + 1) / _trailLength;
      final double opacity = progress * 0.15;
      final double radius = 4.0 + progress * 16.0;

      canvas.drawCircle(
        trail[i],
        radius,
        Paint()
          ..color = pointColor.withValues(alpha: opacity)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawGlow(Canvas canvas) {
    const double glowRadius = 44.0;
    canvas.drawCircle(
      position,
      glowRadius * pulseScale,
      Paint()
        ..color = pointColor.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  void _drawPoint(Canvas canvas) {
    canvas.drawCircle(
      position,
      _pointRadius * pulseScale,
      Paint()
        ..color = pointColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(FocusPointPainter oldDelegate) {
    return position != oldDelegate.position ||
        pulseScale != oldDelegate.pulseScale ||
        pointColor != oldDelegate.pointColor ||
        trail.length != oldDelegate.trail.length ||
        (trail.isNotEmpty &&
            oldDelegate.trail.isNotEmpty &&
            trail.last != oldDelegate.trail.last);
  }
}
