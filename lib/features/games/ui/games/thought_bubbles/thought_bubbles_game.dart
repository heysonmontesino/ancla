import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ThoughtBubblesGame extends StatefulWidget {
  const ThoughtBubblesGame({super.key});

  @override
  State<ThoughtBubblesGame> createState() => _ThoughtBubblesGameState();
}

class _ThoughtBubblesGameState extends State<ThoughtBubblesGame>
    with TickerProviderStateMixin {
  // ─── Constants & Colors ─────────────────────────────────────────────────────
  static const Color _bgStart = Color(0xFF0B0E17);
  static const Color _bgEnd = Color(0xFF0F1220);

  static const List<Map<String, dynamic>> _bubbleColors = [
    {'name': 'Sage', 'color': Color(0xFF8BAF92)},
    {'name': 'Lavender', 'color': Color(0xFFAA96C8)},
    {'name': 'Peach', 'color': Color(0xFFD4A89A)},
    {'name': 'Sky', 'color': Color(0xFF8BB4C8)},
    {'name': 'Mint', 'color': Color(0xFF8CC4B0)},
    {'name': 'Rose', 'color': Color(0xFFC8899A)},
  ];

  // ─── Game State ─────────────────────────────────────────────────────────────
  int _currentLevel = 1;
  int _score = 0;
  bool _isTransitioning = false;
  String? _targetColorName;
  Color? _targetColor;

  final List<_Bubble> _bubbles = [];
  final List<_Particle> _particles = [];
  late final AnimationController _mainController;
  late final AnimationController _transitionController;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateGame);
    _mainController.repeat();

    _transitionController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _startLevel(_currentLevel);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  // ─── Level Logic ────────────────────────────────────────────────────────────
  void _startLevel(int level) {
    _currentLevel = level;
    _score = 0;
    _bubbles.clear();

    if (level == 5 || level == 6) {
      final target = _bubbleColors[math.Random().nextInt(_bubbleColors.length)];
      _targetColorName = target['name'];
      _targetColor = target['color'];
    } else {
      _targetColorName = null;
      _targetColor = null;
    }

    _showLevelTransition();
  }

  void _showLevelTransition() {
    setState(() => _isTransitioning = true);
    _transitionController.forward(from: 0).then((_) {
      if (mounted) setState(() => _isTransitioning = false);
    });
  }

  void _checkLevelProgress() {
    final targets = {1: 10, 2: 15, 3: 15, 4: 15, 5: 20, 6: 20};
    if (_currentLevel < 7 && _score >= (targets[_currentLevel] ?? 999)) {
      _startLevel(_currentLevel + 1);
    }
  }

  // ─── Game Loop ──────────────────────────────────────────────────────────────
  void _updateGame() {
    if (_isTransitioning) return;

    final Size size = MediaQuery.of(context).size;
    final config = _getLevelConfig(_currentLevel);

    // Update particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].update();
      if (_particles[i].opacity <= 0) _particles.removeAt(i);
    }

    // Update bubbles
    for (int i = 0; i < _bubbles.length; i++) {
      _bubbles[i].update(size, DateTime.now().millisecondsSinceEpoch / 1000.0);
    }

    // Spawn bubbles
    if (_bubbles.length < config.maxBubbles) {
      _spawnBubble(size);
    }

    setState(() {});
  }

  void _spawnBubble(Size size) {
    final colorMap = _bubbleColors[math.Random().nextInt(_bubbleColors.length)];
    final config = _getLevelConfig(_currentLevel);

    final bubble = _Bubble(
      x: math.Random().nextDouble() * (size.width - 100) + 50,
      y: size.height + 100,
      size: 80.0 + math.Random().nextDouble() * 40.0,
      color: colorMap['color'],
      colorName: colorMap['name'],
      speed: config.baseSpeed * (0.8 + math.Random().nextDouble() * 0.4),
      entryController: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      )..forward(),
    );
    _bubbles.add(bubble);
  }

  _LevelConfig _getLevelConfig(int level) {
    switch (level) {
      case 1:
        return _LevelConfig(maxBubbles: 2, baseSpeed: 1.5);
      case 2:
        return _LevelConfig(maxBubbles: 3, baseSpeed: 1.5);
      case 3:
        return _LevelConfig(maxBubbles: 3, baseSpeed: 2.2);
      case 4:
        return _LevelConfig(maxBubbles: 4, baseSpeed: 2.2);
      case 5:
        return _LevelConfig(maxBubbles: 4, baseSpeed: 2.2);
      case 6:
        return _LevelConfig(maxBubbles: 5, baseSpeed: 3.0);
      default: // Level 7+
        return _LevelConfig(maxBubbles: 6, baseSpeed: 3.5);
    }
  }

  void _onBubbleTap(_Bubble bubble) {
    if (_isTransitioning) return;

    // Check color constraint in levels 5-6
    if (_targetColorName != null && bubble.colorName != _targetColorName) {
      return; // Optional: could add a subtle "incorrect" wiggle
    }

    HapticFeedback.lightImpact();

    setState(() {
      bubble.isPopping = true;
      _score++;
      // Burst particles
      for (int i = 0; i < 6; i++) {
        _particles.add(_Particle(
          x: bubble.x,
          y: bubble.y,
          color: bubble.color,
        ));
      }
      _bubbles.remove(bubble);
    });

    _checkLevelProgress();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bgStart, _bgEnd],
              ),
            ),
          ),

          // Particles
          CustomPaint(
            painter: _ParticlePainter(particles: _particles),
            size: Size.infinite,
          ),

          // Bubbles
          ..._bubbles.map((b) => Positioned(
                left: b.x - (b.size / 2) + b.wobbleX,
                top: b.y - (b.size / 2),
                child: _BubbleWidget(
                  bubble: b,
                  onTap: () => _onBubbleTap(b),
                ),
              )),

          // Header
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 12),
                if (_targetColorName != null) _buildColorTargetChip(),
              ],
            ),
          ),

          // Level Transition Overlay
          if (_isTransitioning) _buildTransitionOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Column(
            children: [
              Text(
                _currentLevel == 7 ? 'MODO INFINITO' : 'NIVEL $_currentLevel',
                style: GoogleFonts.instrumentSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_score burbujas',
                style: GoogleFonts.instrumentSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48), // Spacer for balance
        ],
      ),
    );
  }

  Widget _buildColorTargetChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Revienta las ',
            style: GoogleFonts.instrumentSans(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _targetColor?.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _targetColor?.withValues(alpha: 0.5) ?? Colors.white10),
            ),
            child: Text(
              _targetColorName!.toUpperCase(),
              style: GoogleFonts.instrumentSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _targetColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionOverlay() {
    return FadeTransition(
      opacity: _transitionController.drive(TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
      ])),
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: Center(
          child: Text(
            _currentLevel == 7 ? 'MODO INFINITO' : 'NIVEL $_currentLevel',
            style: GoogleFonts.instrumentSans(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1.0,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bubble Implementation ────────────────────────────────────────────────────
class _Bubble {
  double x;
  double y;
  double size;
  Color color;
  String colorName;
  double speed;
  double wobbleX = 0;
  bool isPopping = false;
  final AnimationController entryController;

  _Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.colorName,
    required this.speed,
    required this.entryController,
  });

  void update(Size screen, double time) {
    y -= speed;
    wobbleX = math.sin(time * 0.8 + x) * 10;

    if (y < -size) {
      y = screen.height + size;
    }
  }
}

class _BubbleWidget extends StatelessWidget {
  final _Bubble bubble;
  final VoidCallback onTap;

  const _BubbleWidget({required this.bubble, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: bubble.entryController,
        curve: Curves.elasticOut,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: bubble.size,
          height: bubble.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.4, -0.4),
              colors: [
                Colors.white.withValues(alpha: 0.4),
                bubble.color.withValues(alpha: 0.2),
                bubble.color.withValues(alpha: 0.1),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: bubble.color.withValues(alpha: 0.15),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Particle Implementation ──────────────────────────────────────────────────
class _Particle {
  double x, y;
  double vx, vy;
  double opacity = 1.0;
  Color color;

  _Particle({required this.x, required this.y, required this.color})
      : vx = (math.Random().nextDouble() - 0.5) * 6,
        vy = (math.Random().nextDouble() - 0.5) * 6;

  void update() {
    x += vx;
    y += vy;
    opacity -= 0.05;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity.clamp(0, 1));
      canvas.drawCircle(Offset(p.x, p.y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Config Helper ───────────────────────────────────────────────────────────
class _LevelConfig {
  final int maxBubbles;
  final double baseSpeed;

  _LevelConfig({required this.maxBubbles, required this.baseSpeed});
}
