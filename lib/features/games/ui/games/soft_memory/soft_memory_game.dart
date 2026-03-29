import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum _GamePhase { idle, watching, repeating, success, completed }

class SoftMemoryGame extends StatefulWidget {
  const SoftMemoryGame({super.key});

  @override
  State<SoftMemoryGame> createState() => _SoftMemoryGameState();
}

class _SoftMemoryGameState extends State<SoftMemoryGame>
    with TickerProviderStateMixin {
  static const Color _bg = Color(0xFF0B0E17);
  static const int _maxLength = 7;
  static const int _startLength = 2;

  static const List<Color> _colors = [
    Color(0xFF8BAF92), // sage
    Color(0xFFAA96C8), // lavender
    Color(0xFFD4A89A), // peach
    Color(0xFF8BB4C8), // sky
  ];

  // ── State ─────────────────────────────────────────────────────────────────

  _GamePhase _phase = _GamePhase.idle;
  List<int> _sequence = [];
  List<int> _userInput = [];
  String _message = 'Toca "Comenzar" para empezar';
  bool _disposed = false;
  bool _isFadingError = false;

  // ── Animations ────────────────────────────────────────────────────────────

  /// One controller per circle: drives opacity 0.45→1.0 and scale 1.0→1.08.
  late final List<AnimationController> _circleControllers;
  late final List<Animation<double>> _scaleAnims;
  late final List<Animation<double>> _opacityAnims;

  /// Drives the all-circles pulse during success phase.
  late final AnimationController _successController;
  late final Animation<double> _successPulse;

  @override
  void initState() {
    super.initState();

    _circleControllers = List.generate(
      4,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      )..addListener(() => setState(() {})),
    );

    _scaleAnims = _circleControllers
        .map(
          (c) => Tween<double>(begin: 1.0, end: 1.08).animate(
            CurvedAnimation(parent: c, curve: Curves.easeOut),
          ),
        )
        .toList();

    _opacityAnims = _circleControllers
        .map((c) => Tween<double>(begin: 0.45, end: 1.0).animate(c))
        .toList();

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() => setState(() {}));

    _successPulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0),
        weight: 50,
      ),
    ]).animate(_successController);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final c in _circleControllers) {
      c.dispose();
    }
    _successController.dispose();
    super.dispose();
  }

  // ── Game logic ────────────────────────────────────────────────────────────

  void _start() {
    _sequence = _randomSequence(_startLength);
    _userInput = [];
    unawaited(_playSequence());
  }

  List<int> _randomSequence(int length) =>
      List.generate(length, (_) => math.Random().nextInt(4));

  Future<void> _playSequence() async {
    if (_disposed || !mounted) return;

    // Dim all circles before showing sequence
    for (final c in _circleControllers) {
      c.reverse();
    }

    setState(() {
      _phase = _GamePhase.watching;
      _message = 'Observa la secuencia...';
      _userInput = [];
    });

    await Future.delayed(const Duration(milliseconds: 500));

    for (int i = 0; i < _sequence.length; i++) {
      if (_disposed || !mounted) return;

      final ci = _sequence[i];
      _circleControllers[ci].forward();

      await Future.delayed(const Duration(milliseconds: 1200));
      if (_disposed || !mounted) return;

      _circleControllers[ci].reverse();

      await Future.delayed(const Duration(milliseconds: 400));
      if (_disposed || !mounted) return;
    }

    setState(() {
      _phase = _GamePhase.repeating;
      _message = 'Ahora repite la secuencia';
    });
  }

  void _onCircleTap(int index) {
    if (_phase != _GamePhase.repeating) return;

    // Brief visual tap feedback
    _circleControllers[index].forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!_disposed && mounted) _circleControllers[index].reverse();
    });

    final expected = _userInput.length;

    if (index == _sequence[expected]) {
      setState(() => _userInput.add(index));
      if (_userInput.length == _sequence.length) {
        unawaited(_onSuccess());
      }
    } else {
      unawaited(_onError());
    }
  }

  Future<void> _onSuccess() async {
    if (_disposed || !mounted) return;

    // Light up all circles for the pulse
    for (final c in _circleControllers) {
      c.value = 1.0;
    }

    if (_sequence.length >= _maxLength) {
      setState(() {
        _phase = _GamePhase.completed;
        _message = 'Excelente práctica. ¿Otra ronda?';
      });
      return;
    }

    setState(() {
      _phase = _GamePhase.success;
      _message = '¡Bien hecho!';
    });

    await _successController.forward(from: 0);
    if (_disposed || !mounted) return;
    await _successController.reverse();
    if (_disposed || !mounted) return;

    await Future.delayed(const Duration(milliseconds: 600));
    if (_disposed || !mounted) return;

    _sequence.add(math.Random().nextInt(4));
    unawaited(_playSequence());
  }

  Future<void> _onError() async {
    if (_disposed || !mounted) return;

    // Block further input immediately
    setState(() {
      _phase = _GamePhase.watching;
      _isFadingError = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (_disposed || !mounted) return;

    setState(() => _isFadingError = false);

    await Future.delayed(const Duration(milliseconds: 400));
    if (_disposed || !mounted) return;

    unawaited(_playSequence());
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildMessage(),
            Expanded(
              child: Center(child: _buildGrid()),
            ),
            _buildDotsIndicator(),
            _buildControls(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
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
        ],
      ),
    );
  }

  Widget _buildMessage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Padding(
        key: ValueKey(_message),
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          _message,
          textAlign: TextAlign.center,
          style: GoogleFonts.instrumentSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.72),
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final bool tappable = _phase == _GamePhase.repeating;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCircle(0, tappable),
            const SizedBox(width: 22),
            _buildCircle(1, tappable),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCircle(2, tappable),
            const SizedBox(width: 22),
            _buildCircle(3, tappable),
          ],
        ),
      ],
    );
  }

  Widget _buildCircle(int index, bool tappable) {
    final bool isSuccess = _phase == _GamePhase.success;
    final bool isCompleted = _phase == _GamePhase.completed;

    final double scale;
    final double opacity;

    if (_isFadingError) {
      scale = 1.0;
      opacity = 0.2;
    } else if (isSuccess) {
      scale = _successPulse.value;
      opacity = 1.0;
    } else if (isCompleted) {
      scale = 1.0;
      opacity = 1.0;
    } else {
      scale = _scaleAnims[index].value;
      opacity = _opacityAnims[index].value;
    }

    final bool isLit = opacity > 0.75;

    return GestureDetector(
      onTap: tappable ? () => _onCircleTap(index) : null,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _colors[index],
              border: Border.all(
                color: Colors.white.withValues(alpha: isLit ? 0.35 : 0.0),
                width: 2.0,
              ),
              boxShadow: isLit
                  ? [
                      BoxShadow(
                        color: _colors[index].withValues(alpha: 0.50),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDotsIndicator() {
    if (_phase != _GamePhase.repeating) {
      return const SizedBox(height: 32);
    }

    final int total = _sequence.length;
    final int done = _userInput.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done
                  ? Colors.white.withValues(alpha: 0.80)
                  : Colors.white.withValues(alpha: 0.20),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildControls() {
    switch (_phase) {
      case _GamePhase.idle:
        return _actionButton('Comenzar', _start);
      case _GamePhase.completed:
        return _actionButton('Comenzar de nuevo', _start);
      case _GamePhase.watching:
      case _GamePhase.repeating:
      case _GamePhase.success:
        return const SizedBox(height: 48);
    }
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: GoogleFonts.instrumentSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
