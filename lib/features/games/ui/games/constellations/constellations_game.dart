import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constellation_data.dart';
import 'constellations_painter.dart';

class ConstellationsGame extends StatefulWidget {
  const ConstellationsGame({super.key});

  @override
  State<ConstellationsGame> createState() => _ConstellationsGameState();
}

class _ConstellationsGameState extends State<ConstellationsGame>
    with TickerProviderStateMixin {
  static const Color _bg = Color(0xFF0B0E17);
  static const double _tapRadius = 44.0;

  // ── Fixed data ─────────────────────────────────────────────────────────────

  late final List<BackgroundStar> _bgStars;

  // ── Game state ─────────────────────────────────────────────────────────────

  int _constellationIndex = 0;
  int _tapIndex = 0; // stars tapped so far in current constellation
  bool _isTransitioning = false;
  bool _showHistoria = false;
  double _canvasOpacity = 1.0;
  Size _canvasSize = Size.zero;

  // ── Controllers ────────────────────────────────────────────────────────────

  late AnimationController _pulseController;   // active star pulse, repeating
  late AnimationController _lineRevealController; // latest line reveal, 300ms
  late Animation<double> _pulseAnim;

  // ── Helpers ────────────────────────────────────────────────────────────────

  ConstellationData get _current => kConstellations[_constellationIndex];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _bgStars = generateBackgroundStars();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.4),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.4, end: 1.0),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _lineRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _lineRevealController.dispose();
    super.dispose();
  }

  // ── Tap handling ───────────────────────────────────────────────────────────

  void _onCanvasTap(TapDownDetails details) {
    if (_isTransitioning || _showHistoria) return;
    if (_tapIndex >= _current.starCount) return;

    final size = _canvasSize;
    if (size == Size.zero) return;

    final activeStar = _current.stars[_tapIndex];
    final activePos = Offset(
      activeStar.dx * size.width,
      activeStar.dy * size.height,
    );

    if ((details.localPosition - activePos).distance <= _tapRadius) {
      _tapActiveStar();
    }
  }

  void _tapActiveStar() {
    final newIndex = _tapIndex + 1;
    setState(() => _tapIndex = newIndex);

    if (newIndex > 1) {
      _lineRevealController.forward(from: 0);
    }

    if (newIndex == _current.starCount) {
      unawaited(_onComplete());
    }
  }

  // ── Completion flow ────────────────────────────────────────────────────────

  Future<void> _onComplete() async {
    _isTransitioning = true;
    setState(() {});

    // Let the last line finish drawing
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    // Show the historia
    setState(() => _showHistoria = true);
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    // Fade everything out
    setState(() {
      _showHistoria = false;
      _canvasOpacity = 0.0;
    });
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    // Advance to next constellation
    setState(() {
      _constellationIndex = (_constellationIndex + 1) % kConstellations.length;
      _tapIndex = 0;
      _canvasOpacity = 1.0;
      _isTransitioning = false;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
                    child: Text(
                      'Une las estrellas en orden.',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.60),
                        height: 1.4,
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
                  if (_canvasSize != size) _canvasSize = size;
                });

                return AnimatedOpacity(
                  opacity: _canvasOpacity,
                  duration: const Duration(milliseconds: 400),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: _onCanvasTap,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Painter
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: ConstellationsPainter(
                                constellation: _current,
                                tapIndex: _tapIndex,
                                activePulseScale: _isTransitioning
                                    ? 1.0
                                    : _pulseAnim.value,
                                lineReveal: _lineRevealController.value,
                                backgroundStars: _bgStars,
                              ),
                              size: size,
                            );
                          },
                        ),

                        // Historia overlay (always in tree for smooth fade)
                        IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _showHistoria ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 500),
                            child: Align(
                              alignment: const Alignment(0.0, 0.68),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 36,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _current.name,
                                      style: GoogleFonts.instrumentSans(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: _current.color,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _current.historia,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.instrumentSans(
                                        fontSize: 14,
                                        color: Colors.white
                                            .withValues(alpha: 0.65),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Progress dots
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(kConstellations.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _constellationIndex
                          ? Colors.white.withValues(alpha: 0.72)
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
