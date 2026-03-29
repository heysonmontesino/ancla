import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'zen_garden_painter.dart';

class ZenGardenGame extends StatefulWidget {
  const ZenGardenGame({super.key});

  @override
  State<ZenGardenGame> createState() => _ZenGardenGameState();
}

class _ZenGardenLevel {
  const _ZenGardenLevel({
    required this.stoneCount,
    required this.showGuide,
    required this.guideComplexity,
    required this.eraseEveryTwentySeconds,
  });

  final int stoneCount;
  final bool showGuide;
  final int guideComplexity;
  final bool eraseEveryTwentySeconds;
}

class _ZenGardenGameState extends State<ZenGardenGame>
    with TickerProviderStateMixin {
  static const Color _bg = Color(0xFF0B0E17);
  static const Color _sand = Color(0xFFE8DCC8);
  static const Color _sandShade = Color(0xFFC4B49A);
  static const Color _stone = Color(0xFF2A2A35);
  static const Color _stoneBorder = Color(0xFF3A3A45);

  static const List<_ZenGardenLevel> _levels = [
    _ZenGardenLevel(
      stoneCount: 2,
      showGuide: false,
      guideComplexity: 0,
      eraseEveryTwentySeconds: false,
    ),
    _ZenGardenLevel(
      stoneCount: 3,
      showGuide: true,
      guideComplexity: 1,
      eraseEveryTwentySeconds: false,
    ),
    _ZenGardenLevel(
      stoneCount: 4,
      showGuide: true,
      guideComplexity: 2,
      eraseEveryTwentySeconds: false,
    ),
    _ZenGardenLevel(
      stoneCount: 5,
      showGuide: false,
      guideComplexity: 0,
      eraseEveryTwentySeconds: true,
    ),
    _ZenGardenLevel(
      stoneCount: 6,
      showGuide: true,
      guideComplexity: 3,
      eraseEveryTwentySeconds: true,
    ),
  ];

  static const Duration _nextGardenDelay = Duration(seconds: 60);
  static const Duration _eraseInterval = Duration(seconds: 20);

  final List<Offset> _trailPoints = <Offset>[];
  final math.Random _random = math.Random();

  late final AnimationController _stoneController;
  late final AnimationController _trailOpacityController;
  late final AnimationController _sceneController;

  List<ZenStone> _stones = const <ZenStone>[];
  List<ZenGuidePath> _guidePaths = const <ZenGuidePath>[];
  Size _canvasSize = Size.zero;

  int _levelIndex = 0;
  bool _isTransitioning = false;
  bool _showNextGarden = false;

  Timer? _nextGardenTimer;
  Timer? _eraseTimer;

  @override
  void initState() {
    super.initState();
    _stoneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() => setState(() {}));

    _trailOpacityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 0,
    )..addListener(() => setState(() {}));

    _sceneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1,
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nextGardenTimer?.cancel();
    _eraseTimer?.cancel();
    _stoneController.dispose();
    _trailOpacityController.dispose();
    _sceneController.dispose();
    super.dispose();
  }

  _ZenGardenLevel get _currentLevel => _levels[_levelIndex];

  double get _stoneScale =>
      Curves.elasticOut.transform(_stoneController.value.clamp(0, 1));

  String get _subtitle {
    switch (_levelIndex) {
      case 0:
        return 'Traza caminos lentos entre las piedras. Sin objetivo.';
      case 1:
        return 'Sigue el patrón guía con trazos suaves.';
      case 2:
        return 'Más piedras, más respiración, más presencia.';
      case 3:
        return 'El jardín se despeja de a poco. Vuelve a empezar cuando quieras.';
      default:
        return 'Todo junto: guía, más piedras y un jardín que se renueva.';
    }
  }

  void _handleCanvasResize(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if ((_canvasSize.width - size.width).abs() < 1 &&
        (_canvasSize.height - size.height).abs() < 1 &&
        _stones.isNotEmpty) {
      return;
    }

    _canvasSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prepareGarden(animateScene: false);
    });
  }

  Future<void> _prepareGarden({
    required bool animateScene,
  }) async {
    if (_canvasSize == Size.zero || _isTransitioning) return;
    _isTransitioning = true;

    if (animateScene) {
      await _sceneController.animateTo(0);
    }

    _nextGardenTimer?.cancel();
    _eraseTimer?.cancel();
    _showNextGarden = false;

    _trailPoints.clear();
    _trailOpacityController.value = 0;

    _stones = _generateStones(_canvasSize, _currentLevel.stoneCount);
    _guidePaths = _currentLevel.showGuide
        ? _generateGuidePaths(_canvasSize, _stones, _currentLevel.guideComplexity)
        : const <ZenGuidePath>[];

    _stoneController.forward(from: 0);

    _nextGardenTimer = Timer(_nextGardenDelay, () {
      if (mounted) {
        setState(() => _showNextGarden = true);
      }
    });

    if (_currentLevel.eraseEveryTwentySeconds) {
      _eraseTimer = Timer.periodic(_eraseInterval, (_) {
        if (_trailPoints.isNotEmpty && !_isTransitioning) {
          unawaited(_fadeAndClearTrail(const Duration(milliseconds: 800)));
        }
      });
    }

    if (animateScene) {
      await _sceneController.animateTo(1);
    } else {
      _sceneController.value = 1;
    }

    if (mounted) {
      setState(() {});
    }

    _isTransitioning = false;
  }

  List<ZenStone> _generateStones(Size size, int count) {
    final List<ZenStone> stones = <ZenStone>[];
    final Rect safeRect = Rect.fromLTWH(
      48,
      48,
      size.width - 96,
      size.height - 96,
    );

    int attempts = 0;
    while (stones.length < count && attempts < 1000) {
      attempts += 1;
      final double width = 56 + _random.nextDouble() * 34;
      final double height = 48 + _random.nextDouble() * 28;
      final Offset center = Offset(
        safeRect.left + _random.nextDouble() * safeRect.width,
        safeRect.top + _random.nextDouble() * safeRect.height,
      );
      final ZenStone candidate = ZenStone(
        center: center,
        size: Size(width, height),
        rotation: (_random.nextDouble() - 0.5) * 0.55,
      );

      final bool tooClose = stones.any((stone) {
        final double minDistance = math.max(
          80,
          (math.max(stone.size.width, stone.size.height) +
                      math.max(candidate.size.width, candidate.size.height)) /
                  2 +
              18,
        ).toDouble();
        return (stone.center - candidate.center).distance < minDistance;
      });

      if (!tooClose) {
        stones.add(candidate);
      }
    }

    return stones;
  }

  List<ZenGuidePath> _generateGuidePaths(
    Size size,
    List<ZenStone> stones,
    int complexity,
  ) {
    if (stones.isEmpty) return const <ZenGuidePath>[];

    final List<ZenStone> sorted = [...stones]
      ..sort((a, b) => a.center.dx.compareTo(b.center.dx));

    final List<ZenGuidePath> guides = <ZenGuidePath>[
      ZenGuidePath(
        points: [
          Offset(24, size.height * 0.24),
          for (int i = 0; i < sorted.length; i++)
            Offset(
              sorted[i].center.dx,
              sorted[i].center.dy + (i.isEven ? 42 : -42),
            ),
          Offset(size.width - 24, size.height * 0.7),
        ],
      ),
    ];

    if (complexity >= 2) {
      guides.add(
        ZenGuidePath(
          points: [
            Offset(36, size.height * 0.72),
            for (int i = sorted.length - 1; i >= 0; i--)
              Offset(
                sorted[i].center.dx,
                sorted[i].center.dy + (i.isEven ? -56 : 56),
              ),
            Offset(size.width - 36, size.height * 0.28),
          ],
        ),
      );
    }

    if (complexity >= 3) {
      final ZenStone anchor = sorted[sorted.length ~/ 2];
      guides.add(
        ZenGuidePath(
          points: [
            anchor.center + const Offset(-70, 0),
            anchor.center + const Offset(-36, -52),
            anchor.center + const Offset(30, -22),
            anchor.center + const Offset(52, 34),
            anchor.center + const Offset(-8, 64),
          ],
        ),
      );
    }

    return guides;
  }

  bool _isPointInsideStone(Offset point) {
    for (final ZenStone stone in _stones) {
      final double radius =
          math.max(stone.size.width, stone.size.height) / 2 + 8;
      if ((point - stone.center).distance <= radius) {
        return true;
      }
    }
    return false;
  }

  bool _segmentIntersectsStone(Offset start, Offset end) {
    for (final ZenStone stone in _stones) {
      final double radius =
          math.max(stone.size.width, stone.size.height) / 2 + 8;
      if (_distanceToSegment(stone.center, start, end) <= radius) {
        return true;
      }
    }
    return false;
  }

  double _distanceToSegment(Offset point, Offset a, Offset b) {
    final Offset ab = b - a;
    final double lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (point - a).distance;
    final double t = ((point.dx - a.dx) * ab.dx + (point.dy - a.dy) * ab.dy) /
        lengthSquared;
    final double clamped = t.clamp(0, 1);
    final Offset projection = Offset(
      a.dx + ab.dx * clamped,
      a.dy + ab.dy * clamped,
    );
    return (point - projection).distance;
  }

  void _onPanStart(DragStartDetails details) {
    if (_isTransitioning) return;
    final Offset point = details.localPosition;
    if (_isPointInsideStone(point)) return;

    if (_trailPoints.isEmpty) {
      _trailPoints.add(point);
      _trailOpacityController.animateTo(
        1,
        duration: const Duration(milliseconds: 100),
      );
      setState(() {});
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isTransitioning) return;
    final Offset point = details.localPosition;
    if (_isPointInsideStone(point)) return;

    if (_trailPoints.isEmpty) {
      _trailPoints.add(point);
      _trailOpacityController.animateTo(
        1,
        duration: const Duration(milliseconds: 100),
      );
      setState(() {});
      return;
    }

    final Offset last = _trailPoints.last;
    if ((point - last).distance < 4) return;
    if (_segmentIntersectsStone(last, point)) return;

    _trailPoints.add(point);
    setState(() {});
  }

  Future<void> _fadeAndClearTrail(Duration duration) async {
    if (_trailPoints.isEmpty) return;
    await _trailOpacityController.animateTo(0, duration: duration);
    if (!mounted) return;
    _trailPoints.clear();
    _trailOpacityController.value = 0;
    setState(() {});
  }

  Future<void> _goToNextGarden() async {
    if (_isTransitioning) return;
    setState(() => _showNextGarden = false);

    if (_levelIndex < _levels.length - 1) {
      _levelIndex += 1;
    }

    await _prepareGarden(animateScene: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: Colors.white70,
                    ),
                    tooltip: 'Volver',
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jardín Zen',
                          style: GoogleFonts.instrumentSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle,
                          style: GoogleFonts.instrumentSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.62),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _trailPoints.isEmpty || _isTransitioning
                        ? null
                        : () => _fadeAndClearTrail(
                              const Duration(milliseconds: 400),
                            ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _sand,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final Size size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    _handleCanvasResize(size);

                    return Stack(
                      children: [
                        IgnorePointer(
                          ignoring: _isTransitioning,
                          child: GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            child: Opacity(
                              opacity: _sceneController.value,
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  size: size,
                                  painter: ZenGardenPainter(
                                    stones: _stones,
                                    trailPoints: _trailPoints,
                                    guidePaths: _guidePaths,
                                    trailOpacity: _trailOpacityController.value,
                                    stoneScale: _stoneScale,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 14,
                          bottom: 14,
                          child: AnimatedOpacity(
                            opacity: _sceneController.value,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _stone.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _stoneBorder.withValues(alpha: 0.7),
                                ),
                              ),
                              child: Text(
                                'Nivel ${_levelIndex + 1}',
                                style: GoogleFonts.instrumentSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _sand,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 18,
                          child: IgnorePointer(
                            ignoring: !_showNextGarden,
                            child: AnimatedOpacity(
                              opacity: _showNextGarden ? 1 : 0,
                              duration: const Duration(milliseconds: 250),
                              child: Center(
                                child: TextButton(
                                  onPressed: _goToNextGarden,
                                  style: TextButton.styleFrom(
                                    foregroundColor: _sandShade,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: Text(
                                    'Siguiente jardín',
                                    style: GoogleFonts.instrumentSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }
}
