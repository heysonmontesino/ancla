import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'focus_point_painter.dart';

// ── Motion patterns ───────────────────────────────────────────────────────────
//
//  0 — Lissajous:    x = cx + rx·sin(3t + π/2),  y = cy + ry·sin(2t)
//  1 — Figure-8:     x = cx + rx·sin(t),          y = cy + ry·sin(2t)
//  2 — Soft spiral:  r = baseR + amp·sin(t·π),    x/y = polar(r, angle)
//  3 — Circle:       x = cx + rx·cos(t),           y = cy + ry·sin(t)

class FocusPointGame extends StatefulWidget {
  const FocusPointGame({super.key});

  @override
  State<FocusPointGame> createState() => _FocusPointGameState();
}

class _FocusPointGameState extends State<FocusPointGame>
    with TickerProviderStateMixin {
  static const Color _bg = Color(0xFF0B0E17);
  static const double _padding = 60.0;
  static const int _trailLength = 12;

  // ── Color palette (one per pattern, cycles in order) ─────────────────────
  static const List<Color> _pointColors = [
    Color(0xFFAA96C8), // lavender  (pattern 0)
    Color(0xFF8CC4B0), // mint      (pattern 1)
    Color(0xFFD4A89A), // peach     (pattern 2)
    Color(0xFF8BB4C8), // sky       (pattern 3)
  ];

  // ── Pattern state ─────────────────────────────────────────────────────────
  int _currentPattern = 0;
  int _oldPattern = 0;

  // ── Color state ───────────────────────────────────────────────────────────
  Color _currentPointColor = _pointColors[0];
  Color _oldPointColor = _pointColors[0];

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _isPaused = false;
  bool _showInstruction = true;
  bool _showPatternHint = false;
  Size _canvasSize = Size.zero;

  // ── Trail ─────────────────────────────────────────────────────────────────
  final List<Offset> _trail = [];

  // ── Controllers ───────────────────────────────────────────────────────────
  late AnimationController _loopController;  // drives motion, 12s repeat
  late AnimationController _pulseController; // touch feedback, 200ms
  late AnimationController _blendController; // pattern blend, 2s
  late AnimationController _colorController; // color lerp, 1s
  late Animation<double> _pulseAnim;

  Timer? _patternTimer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )
      ..addListener(_onTick)
      ..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 50,
      ),
    ]).animate(_pulseController);

    _blendController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() => setState(() {}));

    _patternTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _advancePattern(),
    );

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showInstruction = false);
    });
  }

  @override
  void dispose() {
    _patternTimer?.cancel();
    _loopController.dispose();
    _pulseController.dispose();
    _blendController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  // ── Pattern advance ───────────────────────────────────────────────────────

  void _advancePattern() {
    if (!mounted) return;
    final next = (_currentPattern + 1) % 4;

    // Capture mid-lerp color as the new "from" color
    final fromColor = Color.lerp(
          _oldPointColor,
          _currentPointColor,
          _colorController.value,
        ) ??
        _currentPointColor;

    setState(() {
      _oldPattern = _currentPattern;
      _currentPattern = next;
      _oldPointColor = fromColor;
      _currentPointColor = _pointColors[next];
      _showPatternHint = true;
    });

    _blendController.forward(from: 0);
    _colorController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showPatternHint = false);
    });
  }

  // ── Motion computation ────────────────────────────────────────────────────

  Offset _computeForPattern(int pattern, double t, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = (size.width / 2) - _padding;
    final ry = (size.height / 2) - _padding;
    final angle = t * 2 * math.pi;

    switch (pattern) {
      case 0: // Lissajous a=3, b=2, δ=π/2
        return Offset(
          cx + rx * math.sin(3.0 * angle + math.pi / 2.0),
          cy + ry * math.sin(2.0 * angle),
        );
      case 1: // Figure-8
        return Offset(
          cx + rx * math.sin(angle),
          cy + ry * math.sin(2.0 * angle),
        );
      case 2: // Soft spiral
        final minR = math.min(rx, ry);
        final r = minR * 0.10 + minR * 0.80 * math.sin(angle * 0.5);
        return Offset(
          cx + r * math.cos(angle),
          cy + r * math.sin(angle),
        );
      case 3: // Simple circle
        return Offset(
          cx + rx * math.cos(angle),
          cy + ry * math.sin(angle),
        );
      default:
        return Offset(cx, cy);
    }
  }

  Offset _currentBlendedPosition(Size size) {
    final blend = _blendController.value;
    if (blend >= 1.0) {
      return _computeForPattern(_currentPattern, _loopController.value, size);
    }
    final posOld = _computeForPattern(
      _oldPattern,
      _loopController.value,
      size,
    );
    final posNew = _computeForPattern(
      _currentPattern,
      _loopController.value,
      size,
    );
    final easedBlend = Curves.easeInOut.transform(blend);
    return Offset.lerp(posOld, posNew, easedBlend)!;
  }

  void _onTick() {
    if (_canvasSize == Size.zero) return;
    final pos = _currentBlendedPosition(_canvasSize);
    setState(() {
      _trail.add(pos);
      if (_trail.length > _trailLength) {
        _trail.removeAt(0);
      }
    });
  }

  // ── Interaction ───────────────────────────────────────────────────────────

  Color get _interpolatedColor =>
      Color.lerp(_oldPointColor, _currentPointColor, _colorController.value) ??
      _currentPointColor;

  void _onPanUpdate(DragUpdateDetails details) {
    if (_trail.isEmpty) return;
    final distance = (details.localPosition - _trail.last).distance;
    if (distance <= 80.0 && !_pulseController.isAnimating) {
      _pulseController.forward(from: 0);
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _loopController.stop();
      } else {
        _loopController.repeat();
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Volver',
                  ),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _showInstruction ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 600),
                      child: Text(
                        'Sigue el punto con tus ojos o con el dedo.',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.60),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Canvas
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_canvasSize != size) {
                    _canvasSize = size;
                  }
                });

                final position = _trail.isNotEmpty
                    ? _trail.last
                    : _computeForPattern(_currentPattern, 0, size);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onPanUpdate: _onPanUpdate,
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: FocusPointPainter(
                              position: position,
                              trail: List.unmodifiable(_trail),
                              pulseScale: _pulseAnim.value,
                              pointColor: _interpolatedColor,
                            ),
                            size: size,
                          );
                        },
                      ),
                    ),

                    // "nuevo patrón" hint
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _showPatternHint ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child: Align(
                          alignment: const Alignment(0.0, 0.72),
                          child: Text(
                            'nuevo patrón',
                            style: GoogleFonts.instrumentSans(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.40),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Pause / continue button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              child: TextButton.icon(
                onPressed: _togglePause,
                icon: Icon(
                  _isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  size: 16,
                  color: Colors.white38,
                ),
                label: Text(
                  _isPaused ? 'Continuar' : 'Pausar',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
