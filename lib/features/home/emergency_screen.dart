import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'data/sos_usage_repository.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _audioAssetPath = 'assets/audio/sos_intervencion.mp3';
  static const Duration _inhaleDuration = Duration(seconds: 4);
  static const Duration _exhaleDuration = Duration(seconds: 6);
  static const Duration _cycleDuration = Duration(seconds: 10);
  static const Duration _syncProbeInterval = Duration(seconds: 2);
  static const double _minDiameter = 130.0;
  static const double _maxDiameter = 250.0;

  late final AnimationController _breatheController;
  late final Animation<double> _breatheAnimation;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AudioPlayer _audioPlayer;

  final Stopwatch _sessionClock = Stopwatch();
  DocumentReference<Map<String, dynamic>>? _sosEventRef;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  Timer? _syncProbeTimer;

  bool _isInhaling = true;
  bool _audioPrepared = false;
  bool _hasStartedExperience = false;
  bool _isLifecycleSuspended = false;
  bool _isRestartingExperience = false;
  int _phaseRunId = 0;
  Duration _pausedAudioPosition = Duration.zero;
  AppLifecycleState? _lastLifecycleState;
  _BreathingPhase _currentPhase = _BreathingPhase.inhale;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _breatheController = AnimationController(vsync: this);
    _breatheAnimation = Tween<double>(begin: _minDiameter, end: _maxDiameter)
        .animate(
          CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
        );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _audioPlayer = AudioPlayer();

    _bindAudioTelemetry();
    unawaited(_registerSosActivationStart());
    _prepareExperience();
    unawaited(_activateWakelock());
  }

  Future<void> _registerSosActivationStart() async {
    _sosEventRef = await SosUsageRepository.registerActivationStart();
  }

  Future<void> _activateWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (error) {
      if (kDebugMode) debugPrint('No se pudo activar el wakelock SOS: $error');
    }
  }

  Future<void> _prepareExperience() async {
    try {
      await _audioPlayer.setAsset(_audioAssetPath);
      _audioPrepared = true;
      _logCriticalEvent(
        'audio_prepared',
        extra: {'durationMs': _audioPlayer.duration?.inMilliseconds},
      );
    } catch (error, stackTrace) {
      if (kDebugMode) debugPrint('No se pudo precargar el audio de emergencia: $error');
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
      _logCriticalEvent('audio_prepare_failed', extra: {'error': error});
    }

    if (!mounted || _hasStartedExperience) {
      return;
    }

    await _startSynchronizedExperience();
  }

  void _bindAudioTelemetry() {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      (state) {
        _logCriticalEvent(
          'audio_state',
          extra: {
            'playing': state.playing,
            'processing': state.processingState.name,
          },
        );

        if (state.processingState == ProcessingState.completed) {
          _logSyncSnapshot('audio_completed');
          unawaited(_restartSynchronizedExperience());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) debugPrint('Error del player SOS: $error');
        if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
        _logCriticalEvent('audio_state_error', extra: {'error': error});
      },
    );
  }

  Future<void> _startSynchronizedExperience() async {
    _hasStartedExperience = true;
    _isLifecycleSuspended = false;
    _currentPhase = _BreathingPhase.inhale;
    _pausedAudioPosition = Duration.zero;
    _breatheController.value = 0.0;
    setState(() => _isInhaling = true);

    if (_audioPrepared) {
      try {
        await _audioPlayer.seek(Duration.zero);
      } catch (error, stackTrace) {
        if (kDebugMode) debugPrint('No se pudo posicionar el audio SOS al inicio: $error');
        if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
        _logCriticalEvent('audio_seek_start_failed', extra: {'error': error});
      }
    }

    _sessionClock
      ..reset()
      ..start();
    _startSyncProbe();
    _logSyncSnapshot('sync_start');

    unawaited(_playAudio());
    unawaited(_runPhase(_BreathingPhase.inhale));
  }

  Future<void> _restartSynchronizedExperience() async {
    if (!mounted ||
        !_hasStartedExperience ||
        _isLifecycleSuspended ||
        _isRestartingExperience) {
      return;
    }

    _isRestartingExperience = true;
    _phaseRunId++;
    _syncProbeTimer?.cancel();
    _currentPhase = _BreathingPhase.inhale;
    _pausedAudioPosition = Duration.zero;
    _breatheController.stop(canceled: false);
    _breatheController.value = 0.0;

    if (mounted && !_isInhaling) {
      setState(() => _isInhaling = true);
    }

    if (_audioPrepared) {
      try {
        await _audioPlayer.pause();
        await _audioPlayer.seek(Duration.zero);
      } catch (error, stackTrace) {
        if (kDebugMode) debugPrint('No se pudo reiniciar el audio SOS: $error');
        if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
        _logCriticalEvent('audio_restart_failed', extra: {'error': error});
      }
    }

    if (!mounted) {
      _isRestartingExperience = false;
      return;
    }

    _sessionClock
      ..reset()
      ..start();
    _startSyncProbe();
    _logSyncSnapshot('sync_restart_after_audio_completed');
    unawaited(_playAudio());
    unawaited(_runPhase(_BreathingPhase.inhale));
    _isRestartingExperience = false;
  }

  Future<void> _runPhase(
    _BreathingPhase phase, {
    Duration? overrideDuration,
  }) async {
    final int runId = ++_phaseRunId;
    final bool shouldInhale = phase == _BreathingPhase.inhale;
    final double target = shouldInhale ? 1.0 : 0.0;
    final Curve curve = shouldInhale ? Curves.easeIn : Curves.easeOut;
    final Duration duration = overrideDuration ?? _durationForPhase(phase);

    _currentPhase = phase;
    if (mounted && _isInhaling != shouldInhale) {
      setState(() => _isInhaling = shouldInhale);
    }
    _logSyncSnapshot('phase_${phase.name}_start');

    try {
      await _breatheController.animateTo(
        target,
        duration: duration,
        curve: curve,
      );
    } on TickerCanceled {
      return;
    }

    if (!mounted || _isLifecycleSuspended || runId != _phaseRunId) {
      return;
    }

    _logSyncSnapshot('phase_${phase.name}_end');
    unawaited(
      _runPhase(shouldInhale ? _BreathingPhase.exhale : _BreathingPhase.inhale),
    );
  }

  Future<void> _handleLifecyclePause(AppLifecycleState state) async {
    if (!_hasStartedExperience || _isLifecycleSuspended) {
      return;
    }

    _isLifecycleSuspended = true;
    _phaseRunId++;
    _sessionClock.stop();
    _syncProbeTimer?.cancel();
    _pausedAudioPosition = _audioPlayer.position;
    _breatheController.stop(canceled: false);
    _logSyncSnapshot(
      'lifecycle_${state.name}_pause',
      extra: {'pausedAudioMs': _pausedAudioPosition.inMilliseconds},
    );

    if (_audioPrepared) {
      try {
        await _audioPlayer.pause();
      } catch (error, stackTrace) {
        if (kDebugMode) debugPrint('No se pudo pausar el audio SOS: $error');
        if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
        _logCriticalEvent('audio_pause_failed', extra: {'error': error});
      }
    }
  }

  Future<void> _handleLifecycleResume() async {
    if (!_hasStartedExperience || !_isLifecycleSuspended) {
      return;
    }

    if (_audioPrepared) {
      try {
        await _audioPlayer.seek(_pausedAudioPosition);
      } catch (error, stackTrace) {
        if (kDebugMode) debugPrint('No se pudo restaurar el audio SOS: $error');
        if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
        _logCriticalEvent('audio_seek_resume_failed', extra: {'error': error});
      }
    }

    if (!mounted) {
      return;
    }

    _isLifecycleSuspended = false;
    _sessionClock.start();
    _startSyncProbe();
    _logSyncSnapshot(
      'lifecycle_resumed',
      extra: {'resumeAudioMs': _pausedAudioPosition.inMilliseconds},
    );

    if (_audioPrepared) {
      unawaited(_playAudio());
    }

    final Duration remainingDuration = _remainingDurationForCurrentPhase();
    unawaited(_runPhase(_currentPhase, overrideDuration: remainingDuration));
  }

  void _startSyncProbe() {
    _syncProbeTimer?.cancel();
    _syncProbeTimer = Timer.periodic(_syncProbeInterval, (_) {
      if (!_isLifecycleSuspended && mounted) {
        _logSyncSnapshot('sync_probe');
      }
    });
  }

  Future<void> _playAudio() async {
    if (!_audioPrepared) {
      _logCriticalEvent('audio_play_skipped_not_prepared');
      return;
    }

    try {
      await _audioPlayer.play();
    } catch (error, stackTrace) {
      if (kDebugMode) debugPrint('No se pudo reproducir el audio SOS: $error');
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
      _logCriticalEvent('audio_play_failed', extra: {'error': error});
    }
  }

  Duration _durationForPhase(_BreathingPhase phase) {
    return phase == _BreathingPhase.inhale ? _inhaleDuration : _exhaleDuration;
  }

  Duration _remainingDurationForCurrentPhase() {
    final double value = _breatheController.value.clamp(0.0, 1.0);
    final double phaseProgress = _currentPhase == _BreathingPhase.inhale
        ? _invertCurveProgress(curve: Curves.easeIn, transformedValue: value)
        : _invertCurveProgress(
            curve: Curves.easeOut,
            transformedValue: 1.0 - value,
          );
    final double remainingFraction = 1.0 - phaseProgress;

    if (remainingFraction <= 0) {
      _currentPhase = _currentPhase == _BreathingPhase.inhale
          ? _BreathingPhase.exhale
          : _BreathingPhase.inhale;
      return _durationForPhase(_currentPhase);
    }

    return _scaleDuration(_durationForPhase(_currentPhase), remainingFraction);
  }

  Duration _animationCyclePosition() {
    final double value = _breatheController.value.clamp(0.0, 1.0);
    if (_currentPhase == _BreathingPhase.inhale) {
      final double phaseProgress = _invertCurveProgress(
        curve: Curves.easeIn,
        transformedValue: value,
      );
      return _scaleDuration(_inhaleDuration, phaseProgress);
    }

    return _inhaleDuration +
        _scaleDuration(
          _exhaleDuration,
          _invertCurveProgress(
            curve: Curves.easeOut,
            transformedValue: 1.0 - value,
          ),
        );
  }

  Duration _scaleDuration(Duration duration, double factor) {
    final int micros = (duration.inMicroseconds * factor).round();
    return Duration(microseconds: micros.clamp(0, duration.inMicroseconds));
  }

  int _normalizeCycleDriftMs(int driftMs) {
    final int halfCycleMs = _cycleDuration.inMilliseconds ~/ 2;
    final int cycleMs = _cycleDuration.inMilliseconds;

    if (driftMs > halfCycleMs) {
      return driftMs - cycleMs;
    }
    if (driftMs < -halfCycleMs) {
      return driftMs + cycleMs;
    }

    return driftMs;
  }

  double _invertCurveProgress({
    required Curve curve,
    required double transformedValue,
  }) {
    double lower = 0.0;
    double upper = 1.0;

    for (int i = 0; i < 20; i++) {
      final double midpoint = (lower + upper) / 2;
      final double curveValue = curve.transform(midpoint);

      if (curveValue < transformedValue) {
        lower = midpoint;
      } else {
        upper = midpoint;
      }
    }

    return (lower + upper) / 2;
  }

  void _logSyncSnapshot(String event, {Map<String, Object?> extra = const {}}) {
    final int sessionMs = _sessionClock.elapsedMilliseconds;
    final int expectedCycleMs = sessionMs % _cycleDuration.inMilliseconds;
    final int animationCycleMs = _animationCyclePosition().inMilliseconds;
    final int animationDriftMs = _normalizeCycleDriftMs(
      animationCycleMs - expectedCycleMs,
    );
    final int audioMs = _audioPlayer.position.inMilliseconds;

    _logCriticalEvent(
      event,
      extra: {
        'sessionMs': sessionMs,
        'audioMs': audioMs,
        'audioDriftMs': audioMs - sessionMs,
        'expectedCycleMs': expectedCycleMs,
        'animationCycleMs': animationCycleMs,
        'animationDriftMs': animationDriftMs,
        ...extra,
      },
    );
  }

  void _logCriticalEvent(
    String event, {
    Map<String, Object?> extra = const {},
  }) {
    final Map<String, Object?> payload = <String, Object?>{
      'event': event,
      'phase': _currentPhase.name,
      'breathValue': _breatheController.value.toStringAsFixed(3),
      'audioPlaying': _audioPlayer.playing,
      'lifecycle': _lastLifecycleState?.name ?? 'none',
      ...extra,
    };

    final String line = payload.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' | ');
    if (kDebugMode) debugPrint('[SOS] $line');

    // Telemetría a Firebase Analytics (solo si no es un probe repetitivo para evitar ruido)
    if (event != 'sync_probe' && event != 'audio_state') {
      final Map<String, Object> params = <String, Object>{
        'sos_action': event,
        'sos_phase': _currentPhase.name,
        'audio_playing': _audioPlayer.playing ? 'true' : 'false',
      };

      // Agregar extras sanitizados (no nulls para Firebase)
      for (final MapEntry<String, Object?> entry in extra.entries) {
        final Object? value = entry.value;
        if (value != null) {
          params[entry.key] = value;
        }
      }

      unawaited(
        FirebaseAnalytics.instance.logEvent(
          name: 'sos_feature_event',
          parameters: params,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    _logCriticalEvent('lifecycle_${state.name}');

    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_handleLifecycleResume());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_handleLifecyclePause(state));
    }
  }

  @override
  void dispose() {
    final Duration totalDuration = _sessionClock.elapsed;
    final bool completedMinimumInteraction = totalDuration >= _cycleDuration;
    unawaited(
      SosUsageRepository.registerActivationEnd(
        eventRef: _sosEventRef,
        duration: totalDuration,
        completedMinimumInteraction: completedMinimumInteraction,
      ),
    );
    WidgetsBinding.instance.removeObserver(this);
    _syncProbeTimer?.cancel();
    _playerStateSubscription?.cancel();
    _sessionClock.stop();
    _breatheController.dispose();
    _fadeController.dispose();
    _audioPlayer.dispose();
    unawaited(WakelockPlus.disable());
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _makeEmergencyCall() async {
    final Uri url = Uri.parse('tel:106');
    try {
      final bool canCall = await canLaunchUrl(url);
      if (canCall) {
        await launchUrl(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se pudo iniciar la llamada. Marca 106 manualmente.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              backgroundColor: const Color(0xFF7B1A1A),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al llamar: verifica permisos o marca 106 manualmente.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
            backgroundColor: const Color(0xFF7B1A1A),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundDarkness = Color(0xFF080E0B);

    return Scaffold(
      backgroundColor: backgroundDarkness,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Layer 1: Base
            Positioned.fill(
              child: Container(color: backgroundDarkness),
            ),
            Positioned.fill(
              child: Stack(
                children: [
                  // ── Back button ───────────────────────────────────────────────
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20, top: 8),
                      child: Semantics(
                        label: 'Volver al dashboard',
                        button: true,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Core breathing UI — centered ──────────────────────────────
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Breathing orb
                        AnimatedBuilder(
                          animation: _breatheAnimation,
                          builder: (context, child) {
                            final double d = _breatheAnimation.value;
                            final double progress = _breatheController.value;
                            final double glowOpacity = 0.12 + progress * 0.22;

                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: _maxDiameter + 60,
                                  height: _maxDiameter + 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(
                                        0xFF4CAF7D,
                                      ).withValues(alpha: 0.07),
                                      width: 1,
                                    ),
                                  ),
                                ),

                                Container(
                                  width: d + 55,
                                  height: d + 55,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(
                                      0xFF1A5C3A,
                                    ).withValues(alpha: glowOpacity * 0.4),
                                  ),
                                ),

                                SizedBox(
                                  width: d,
                                  height: d,
                                  child: CustomPaint(
                                    painter: _OrganicBlobPainter(
                                      progress: progress,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 56),

                        // "Respirar" — Jakarta Sans
                        Text(
                          _isInhaling ? 'Respirar' : 'Exhalar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Instruction text — swaps on inhale/exhale
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            _isInhaling
                                ? 'Inhala mientras el círculo crece'
                                : 'Exhala mientras el círculo se contrae',
                            key: ValueKey(_isInhaling),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.4),
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Cycle indicator dots
                        _BreathingDots(breatheController: _breatheController),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _SOSCrisisFooter(
        onCall: _makeEmergencyCall,
      ),
    );
  }
}

class _OrganicBlobPainter extends CustomPainter {
  final double progress;

  _OrganicBlobPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final List<double> radiusOffsets = [
      0.88 + 0.14 * progress,
      1.08 - 0.10 * progress,
      0.82 + 0.18 * progress,
      1.12 - 0.16 * progress,
      0.78 + 0.20 * progress,
      1.06 - 0.08 * progress,
      0.84 + 0.16 * progress,
      1.10 - 0.12 * progress,
    ];

    final path = Path();
    const int points = 8;
    final List<Offset> pts = [];

    for (int i = 0; i < points; i++) {
      final double angle = (i / points) * 2 * pi - pi / 2;
      final double rad = r * radiusOffsets[i];
      pts.add(Offset(cx + rad * cos(angle), cy + rad * sin(angle)));
    }

    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < points; i++) {
      final Offset prev = pts[(i - 1 + points) % points];
      final Offset curr = pts[i];
      final Offset next = pts[(i + 1) % points];
      final Offset next2 = pts[(i + 2) % points];

      final Offset ctrl1 = Offset(
        curr.dx + (next.dx - prev.dx) / 3.2,
        curr.dy + (next.dy - prev.dy) / 3.2,
      );
      final Offset ctrl2 = Offset(
        next.dx - (next2.dx - curr.dx) / 3.2,
        next.dy - (next2.dy - curr.dy) / 3.2,
      );
      path.cubicTo(
        ctrl1.dx,
        ctrl1.dy,
        ctrl2.dx,
        ctrl2.dy,
        next.dx,
        next.dy,
      );
    }
    path.close();

    final Paint basePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        radius: 0.85,
        colors: const [
          Color(0xFF3D7A5E),
          Color(0xFF1A3D2B),
          Color(0xFF0A1F15),
          Color(0xFF060E0A),
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(path, basePaint);

    final Paint highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.42, -0.45),
        radius: 0.55,
        colors: [
          const Color(0xFFB4DCC8).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..blendMode = BlendMode.screen;
    canvas.drawPath(path, highlightPaint);

    final Paint shadowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.55, 0.60),
        radius: 0.6,
        colors: [
          Colors.black.withValues(alpha: 0.45),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawPath(path, shadowPaint);

    final Paint specPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.38, -0.42),
        radius: 0.22,
        colors: [
          const Color(0xFFDCF5E8).withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawPath(path, specPaint);

    canvas.restore();

    final Paint borderPaint = Paint()
      ..color = const Color(0xFF7BBFA0).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_OrganicBlobPainter old) => old.progress != progress;
}

enum _BreathingPhase { inhale, exhale }

// ─── Breathing Cycle Dots ────────────────────────────────────────────────────

class _BreathingDots extends StatelessWidget {
  final AnimationController breatheController;

  const _BreathingDots({required this.breatheController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: breatheController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final threshold = (i + 1) / 5.0;
            final isFilled = breatheController.value >= threshold - 0.01;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isFilled ? 20 : 4,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isFilled
                    ? const Color(0xFF7BBFA0)
                    : Colors.white.withValues(alpha: 0.2),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SOSCrisisFooter extends StatelessWidget {
  final VoidCallback onCall;

  const _SOSCrisisFooter({required this.onCall});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2623),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEF6B73).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFFEF6B73),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistencia inmediata',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '¿Deseas contactar con emergencias?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          _ActionButton(label: 'LLAMAR 106', onTap: onCall),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEF6B73).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFEF6B73).withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFEF6B73),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
