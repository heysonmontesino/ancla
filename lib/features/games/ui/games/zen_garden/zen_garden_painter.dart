import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class ZenStone {
  const ZenStone({
    required this.center,
    required this.size,
    required this.rotation,
  });

  final Offset center;
  final Size size;
  final double rotation;
}

class ZenGuidePath {
  const ZenGuidePath({required this.points});

  final List<Offset> points;
}

class ZenGardenPainter extends CustomPainter {
  const ZenGardenPainter({
    required this.stones,
    required this.trailPoints,
    required this.guidePaths,
    required this.trailOpacity,
    required this.stoneScale,
  });

  static const Color _background = Color(0xFF0B0E17);
  static const Color _sand = Color(0xFFE8DCC8);
  static const Color _sandShade = Color(0xFFC4B49A);
  static const Color _stoneFill = Color(0xFF2A2A35);
  static const Color _stoneBorder = Color(0xFF3A3A45);

  final List<ZenStone> stones;
  final List<Offset> trailPoints;
  final List<ZenGuidePath> guidePaths;
  final double trailOpacity;
  final double stoneScale;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final RRect sandRRect = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(28),
    );

    canvas.drawRect(bounds, Paint()..color = _background);
    canvas.drawRRect(sandRRect, Paint()..color = _sand);

    canvas.save();
    canvas.clipRRect(sandRRect);

    _paintTexture(canvas, size);
    _paintGuidePaths(canvas);
    _paintTrail(canvas);
    _paintStones(canvas);

    canvas.restore();
  }

  void _paintTexture(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    for (double y = 18; y < size.height; y += 12) {
      final double wobble = math.sin(y / 34) * 6;
      canvas.drawLine(
        Offset(-8, y + wobble),
        Offset(size.width + 8, y + wobble),
        linePaint,
      );
    }
  }

  void _paintGuidePaths(Canvas canvas) {
    if (guidePaths.isEmpty) return;

    final Paint guidePaint = Paint()
      ..color = _sandShade.withValues(alpha: 0.42)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final ZenGuidePath guide in guidePaths) {
      if (guide.points.length < 2) continue;
      final Path path = _buildSmoothPath(guide.points);
      for (final PathMetric metric in path.computeMetrics()) {
        double distance = 0;
        while (distance < metric.length) {
          final double next = math.min(distance + 8, metric.length);
          final Path extract = metric.extractPath(distance, next);
          canvas.drawPath(extract, guidePaint);
          distance += 14;
        }
      }
    }
  }

  void _paintTrail(Canvas canvas) {
    if (trailPoints.length < 2 || trailOpacity <= 0) return;

    final Path path = _buildSmoothPath(trailPoints);
    final Paint shadowPaint = Paint()
      ..color = _sandShade.withValues(alpha: 0.14 * trailOpacity)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final Paint trailPaint = Paint()
      ..color = _sandShade.withValues(alpha: 0.95 * trailOpacity)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, trailPaint);
  }

  void _paintStones(Canvas canvas) {
    for (final ZenStone stone in stones) {
      canvas.save();
      canvas.translate(stone.center.dx, stone.center.dy);
      canvas.rotate(stone.rotation);
      canvas.scale(stoneScale, stoneScale);

      final Rect stoneRect = Rect.fromCenter(
        center: Offset.zero,
        width: stone.size.width,
        height: stone.size.height,
      );

      final Path stonePath = Path()..addOval(stoneRect);

      canvas.drawPath(
        stonePath.shift(const Offset(0, 6)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );

      canvas.drawPath(stonePath, Paint()..color = _stoneFill);
      canvas.drawPath(
        stonePath,
        Paint()
          ..color = _stoneBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      canvas.restore();
    }
  }

  Path _buildSmoothPath(List<Offset> points) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    for (int i = 1; i < points.length - 1; i++) {
      final Offset current = points[i];
      final Offset next = points[i + 1];
      final Offset midPoint = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, midPoint.dx, midPoint.dy);
    }

    final Offset beforeLast = points[points.length - 2];
    final Offset last = points.last;
    path.quadraticBezierTo(
      beforeLast.dx,
      beforeLast.dy,
      last.dx,
      last.dy,
    );
    return path;
  }

  @override
  bool shouldRepaint(covariant ZenGardenPainter oldDelegate) {
    return oldDelegate.stones != stones ||
        oldDelegate.trailPoints != trailPoints ||
        oldDelegate.guidePaths != guidePaths ||
        oldDelegate.trailOpacity != trailOpacity ||
        oldDelegate.stoneScale != stoneScale;
  }
}
