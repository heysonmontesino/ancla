import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color_zones_painter.dart';

class ColorZonesGame extends StatefulWidget {
  const ColorZonesGame({super.key});

  @override
  State<ColorZonesGame> createState() => _ColorZonesGameState();
}

class _ColorZonesGameState extends State<ColorZonesGame>
    with TickerProviderStateMixin {
  static const Color _bg = Color(0xFF0B0E17);

  // ── Level state ────────────────────────────────────────────────────────────

  int _currentLevel = 1;
  bool _isTransitioning = false;
  double _canvasOpacity = 1.0;
  bool _showLevelLabel = false;

  // ── Per-zone animation state ───────────────────────────────────────────────

  late List<Color> _fromColors;
  late List<Color> _toColors;
  late List<Color> _zoneTargetColors;
  late List<AnimationController> _controllers;
  int _panZone = -1;

  // ── Palette cycling ────────────────────────────────────────────────────────

  static const List<List<Color>> _palettes = [paletteA, paletteB, paletteC];

  // ── Derived ────────────────────────────────────────────────────────────────

  int get _zoneCount {
    if (_currentLevel == 1) return 8;
    if (_currentLevel == 2) return 12;
    return 16;
  }

  List<Color> get _activePalette {
    if (_currentLevel <= 3) return paletteA;
    return _palettes[(_currentLevel - 4) % 3];
  }

  List<Color> get _animatedColors {
    return List.generate(_zoneCount, (i) {
      final t = _controllers[i].value;
      return Color.lerp(_fromColors[i], _toColors[i], t) ?? therapeuticNeutral;
    });
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _controllers = [];
    _fromColors = [];
    _toColors = [];
    _zoneTargetColors = [];
    _initLevel();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Level setup ────────────────────────────────────────────────────────────

  void _initLevel() {
    for (final c in _controllers) {
      c.dispose();
    }

    final count = _zoneCount;
    final palette = _activePalette;

    _zoneTargetColors = buildZoneTargetColors(count, palette);
    _fromColors = List.filled(count, therapeuticNeutral);
    _toColors = List.filled(count, therapeuticNeutral);
    _panZone = -1;

    _controllers = List.generate(
      count,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      )..addListener(() => setState(() {})),
    );
  }

  // ── Interaction ────────────────────────────────────────────────────────────

  void _colorZone(int index) {
    if (_isTransitioning) return;

    final current = Color.lerp(
          _fromColors[index],
          _toColors[index],
          _controllers[index].value,
        ) ??
        therapeuticNeutral;

    final isColored = _toColors[index] == _zoneTargetColors[index];
    final next = isColored ? therapeuticNeutral : _zoneTargetColors[index];

    _fromColors[index] = current;
    _toColors[index] = next;
    _controllers[index].forward(from: 0);

    if (!isColored) {
      _checkCompletion();
    }
  }

  void _checkCompletion() {
    if (_isTransitioning) return;
    for (int i = 0; i < _zoneCount; i++) {
      if (_toColors[i] != _zoneTargetColors[i]) return;
    }
    // Set guard synchronously before async work
    _isTransitioning = true;
    unawaited(_runLevelTransition());
  }

  void _onTapDown(TapDownDetails details, Size size) {
    if (_isTransitioning) return;
    final zone = ColorZonesPainter(
      zoneColors: _animatedColors,
      zoneCount: _zoneCount,
    ).findZone(details.localPosition, size);
    if (zone != -1) _colorZone(zone);
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (_isTransitioning) return;
    final zone = ColorZonesPainter(
      zoneColors: _animatedColors,
      zoneCount: _zoneCount,
    ).findZone(details.localPosition, size);
    if (zone != -1 && zone != _panZone) {
      _panZone = zone;
      _colorZone(zone);
    }
  }

  void _onPanEnd(DragEndDetails _) {
    _panZone = -1;
  }

  void _reset() {
    if (_isTransitioning) return;
    for (int i = 0; i < _zoneCount; i++) {
      final current = Color.lerp(
            _fromColors[i],
            _toColors[i],
            _controllers[i].value,
          ) ??
          therapeuticNeutral;
      _fromColors[i] = current;
      _toColors[i] = therapeuticNeutral;
      _controllers[i].forward(from: 0);
    }
    _panZone = -1;
  }

  // ── Level transition ───────────────────────────────────────────────────────

  Future<void> _runLevelTransition() async {
    // _isTransitioning already set to true by caller
    setState(() {}); // rebuild to disable interactions immediately

    // Let the last zone's color animation settle
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Fade out canvas
    setState(() => _canvasOpacity = 0.0);
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    // Advance level, reinit zones, show label
    _currentLevel += 1;
    _initLevel();
    setState(() => _showLevelLabel = true);

    // Hold level label visible
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // Hide label and fade in fresh canvas
    setState(() {
      _showLevelLabel = false;
      _canvasOpacity = 1.0;
    });

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    setState(() => _isTransitioning = false);
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        key: ValueKey(_currentLevel),
                        _currentLevel == 1
                            ? 'Toca las zonas. No hay forma incorrecta.'
                            : 'Nivel $_currentLevel — sigue coloreando.',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.70),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Canvas area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Zones canvas
                    AnimatedOpacity(
                      opacity: _canvasOpacity,
                      duration: const Duration(milliseconds: 400),
                      child: GestureDetector(
                        onTapDown: (d) => _onTapDown(d, size),
                        onPanUpdate: (d) => _onPanUpdate(d, size),
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          painter: ColorZonesPainter(
                            zoneColors: _animatedColors,
                            zoneCount: _zoneCount,
                          ),
                          size: size,
                        ),
                      ),
                    ),

                    // Level label overlay (always in tree for smooth fade)
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _showLevelLabel ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Center(
                          child: Text(
                            'Nivel $_currentLevel',
                            style: GoogleFonts.instrumentSans(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.80),
                              letterSpacing: -0.5,
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

          // Reset button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              child: TextButton(
                onPressed: _isTransitioning ? null : _reset,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white38,
                  textStyle: GoogleFonts.instrumentSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                child: const Text('Limpiar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
