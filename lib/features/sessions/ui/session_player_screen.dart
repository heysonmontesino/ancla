import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../home/emergency_screen.dart';
import '../controllers/session_playback_controller.dart';
import '../models/audio_session.dart';
import '../../../core/ui/widgets/pill_toast.dart';
import '../models/session_background_sound.dart';

class SessionPlayerScreen extends StatefulWidget {
  final AudioSession session;

  const SessionPlayerScreen({super.key, required this.session});

  @override
  State<SessionPlayerScreen> createState() => _SessionPlayerScreenState();
}

class _SessionPlayerScreenState extends State<SessionPlayerScreen> {
  late final SessionPlaybackController _controller;
  bool _wakelockEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = SessionPlaybackController.instance;
    _controller.addListener(_handleControllerChanged);
    unawaited(_controller.openSession(widget.session));
  }

  @override
  void didUpdateWidget(covariant SessionPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id) {
      unawaited(_controller.openSession(widget.session));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (_wakelockEnabled) {
      unawaited(WakelockPlus.disable());
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    _syncWakelock();
    setState(() {});
  }

  void _syncWakelock() {
    final bool shouldBeEnabled = _controller.isPlaybackActive;
    if (shouldBeEnabled == _wakelockEnabled) return;
    _wakelockEnabled = shouldBeEnabled;
    unawaited(_applyWakelock(shouldBeEnabled));
  }

  Future<void> _applyWakelock(bool enabled) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'No se pudo ${enabled ? 'activar' : 'desactivar'} el wakelock: $error',
        );
      }
    }
  }

  Future<void> _toggleBackground() async {
    final bool success = await _controller.toggleBackground();
    if (!success && mounted) {
      _showMessage('No se pudo activar el ambiente seleccionado.');
    }
  }

  Future<void> _changeBackgroundSound(SessionBackgroundSound sound) async {
    final bool success = await _controller.changeBackgroundSound(sound);
    if (!success && mounted) {
      _showMessage('No se pudo cargar el ambiente seleccionado.');
    }
  }

  Future<void> _setBackgroundVolume(double value) async {
    await _controller.setBackgroundVolume(value);
  }

  Future<void> _seekVoice(Duration position) async {
    await _controller.seekVoice(position);
  }

  Future<void> _playSession() async {
    try {
      await _controller.play();
    } on SessionPlaybackException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    }
  }

  Future<void> _pauseSession() async {
    // Parche: pausar solo la voz para permitir 'piso acustico' persistente.
    await _controller.pauseVoice(keepBackground: true);
  }

  Future<void> _stopAndExitSession() async {
    await _controller.closeSession();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _togglePlay() async {
    if (_controller.isPlaybackActive) {
      await _pauseSession();
    } else {
      await _playSession();
    }
  }

  void _showMessage(String message) {
    PillToast.show(context, message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundBase = Color(0xFF05070A);
    const Color foreground = Color(0xFFEDF2F7);
    const Color primary = Color(0xFF7F9CF5);
    const Color secondary = Color(0xFF111524);
    const Color muted = Color(0xFF121620);
    const Color mutedForeground = Color(0xFF718096);

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: backgroundBase,
        floatingActionButton: Semantics(
          label: 'Botón de emergencia SOS',
          button: true,
          child: FloatingActionButton.small(
            heroTag: 'sos_player',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EmergencyScreen(),
              ),
            ),
            backgroundColor: const Color(0xFF7B1A1A),
            child: const Icon(
              Icons.emergency_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: widget.session.coverImageUrl != null &&
                        widget.session.coverImageUrl!.startsWith('http')
                    ? Image.network(
                        widget.session.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset(
                          widget.session.category.coverImagePath,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        widget.session.category.coverImagePath,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      backgroundBase.withValues(alpha: 0.70),
                      backgroundBase.withValues(alpha: 0.92),
                      backgroundBase.withValues(alpha: 0.98),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isCompact =
                      constraints.maxHeight < 760 || constraints.maxWidth < 400;
                  final double horizontalPadding = isCompact ? 24 : 32;
                  final double heroSize =
                      (constraints.maxWidth * (isCompact ? 0.68 : 0.74)).clamp(
                        260.0,
                        320.0,
                      );
                  final double playButtonSize = isCompact ? 92 : 96;

                  return SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: isCompact ? 24 : 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              isCompact ? 10 : 16,
                              horizontalPadding,
                              0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildHeaderButton(
                                  icon: Icons.arrow_back_ios_new_rounded,
                                  onTap: () => Navigator.of(context).maybePop(),
                                  foreground: foreground,
                                  semanticLabel: 'Cerrar y volver a la biblioteca',
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'MODO RECUPERACION',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: mutedForeground,
                                        letterSpacing: 2.6,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.10,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        widget.session.categoryDisplay
                                            .toUpperCase(),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: primary,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                          ),
                          SizedBox(height: isCompact ? 26 : 34),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: heroSize,
                                  height: heroSize,
                                  child: ClipOval(
                                    child: SizedBox(
                                      width: heroSize * 0.85,
                                      height: heroSize * 0.85,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          widget.session.coverImageUrl != null &&
                                                  widget.session.coverImageUrl!
                                                      .startsWith('http')
                                              ? Image.network(
                                                  widget.session.coverImageUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                          stackTrace) =>
                                                      Image.asset(
                                                    widget.session.category
                                                        .coverImagePath,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : Image.asset(
                                                  widget.session.category
                                                      .coverImagePath,
                                                  fit: BoxFit.cover,
                                                ),
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.10,
                                                ),
                                                width: 1.0,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isCompact ? 30 : 38),
                                Text(
                                  widget.session.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isCompact ? 31 : 34,
                                    fontWeight: FontWeight.w700,
                                    color: foreground,
                                    letterSpacing: -1.0,
                                    height: 1.0,
                                  ),
                                ),
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, _) {
                                    final double sliderMax =
                                        _controller.duration.inMilliseconds > 0
                                        ? _controller.duration.inMilliseconds
                                              .toDouble()
                                        : 1;
                                    final double sliderValue = _controller
                                        .position
                                        .inMilliseconds
                                        .clamp(0, sliderMax.toInt())
                                        .toDouble();

                                    return Column(
                                      children: [
                                        if (_controller.loadError != null) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            _controller.loadError!,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: mutedForeground.withValues(
                                                alpha: 0.92,
                                              ),
                                              height: 1.45,
                                            ),
                                          ),
                                        ] else if (_controller
                                            .isVoiceCompleted) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            'La guia termino. Puedes seguir descansando.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: mutedForeground.withValues(
                                                alpha: 0.92,
                                              ),
                                              height: 1.45,
                                            ),
                                          ),
                                        ],
                                        SizedBox(height: isCompact ? 22 : 28),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 260,
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    _formatDuration(
                                                      _controller.position,
                                                    ),
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          fontSize: isCompact
                                                              ? 44
                                                              : 52,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: foreground,
                                                          letterSpacing: -2.6,
                                                          height: 0.95,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 8,
                                                        ),
                                                    child: Text(
                                                      '/ ${_formatDuration(_controller.duration)}',
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 22,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                mutedForeground
                                                                    .withValues(
                                                                      alpha:
                                                                          0.22,
                                                                    ),
                                                            height: 1.0,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              SliderTheme(
                                                data: SliderTheme.of(context).copyWith(
                                                  trackHeight: 2,
                                                  inactiveTrackColor: Colors
                                                      .white
                                                      .withValues(alpha: 0.05),
                                                  activeTrackColor: primary
                                                      .withValues(alpha: 0.40),
                                                  thumbColor: primary,
                                                  overlayColor: primary
                                                      .withValues(alpha: 0.10),
                                                  thumbShape:
                                                      const RoundSliderThumbShape(
                                                        enabledThumbRadius: 0,
                                                      ),
                                                  overlayShape:
                                                      const RoundSliderOverlayShape(
                                                        overlayRadius: 14,
                                                      ),
                                                ),
                                                child: Slider(
                                                  value: sliderValue,
                                                  max: sliderMax,
                                                  onChanged: _controller.isReady
                                                      ? (value) => _seekVoice(
                                                          Duration(
                                                            milliseconds: value
                                                                .toInt(),
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: isCompact ? 34 : 40),
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.fromLTRB(
                                            horizontalPadding,
                                            isCompact ? 28 : 34,
                                            horizontalPadding,
                                            isCompact ? 24 : 28,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                backgroundBase.withValues(
                                                  alpha: 0.0,
                                                ),
                                                backgroundBase.withValues(
                                                  alpha: 0.95,
                                                ),
                                                backgroundBase,
                                              ],
                                              stops: const [0.0, 0.18, 1.0],
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  _buildTransportButton(
                                                    icon: Icons
                                                        .skip_previous_rounded,
                                                    onTap: () => _seekVoice(
                                                      Duration.zero,
                                                    ),
                                                    foreground: foreground,
                                                    semanticLabel: 'Reiniciar guía de audio',
                                                  ),
                                                  SizedBox(
                                                    width: isCompact ? 28 : 34,
                                                  ),
                                                  Semantics(
                                                    label: _controller.isPlaybackActive ? 'Pausar audio' : 'Reproducir audio',
                                                    button: true,
                                                    child: GestureDetector(
                                                      onTap: _togglePlay,
                                                      child: AnimatedScale(
                                                        duration: const Duration(
                                                          milliseconds: 180,
                                                        ),
                                                        scale:
                                                            _controller
                                                                .isPlaybackActive
                                                            ? 1.02
                                                            : 1.0,
                                                        child: Container(
                                                          width: playButtonSize,
                                                          height: playButtonSize,
                                                          decoration: BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            color: primary,
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: primary
                                                                    .withValues(
                                                                      alpha: 0.20,
                                                                    ),
                                                                blurRadius: 30,
                                                                spreadRadius: 1,
                                                              ),
                                                            ],
                                                          ),
                                                          child: Icon(
                                                            _controller
                                                                    .isPlaybackActive
                                                                ? Icons
                                                                      .pause_rounded
                                                                : Icons
                                                                      .play_arrow_rounded,
                                                            color: backgroundBase,
                                                            size: 42,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: isCompact ? 28 : 34,
                                                  ),
                                                  _buildTransportButton(
                                                    icon: Icons.close_rounded,
                                                    onTap: _stopAndExitSession,
                                                    foreground: foreground,
                                                    semanticLabel: 'Cerrar reproductor',
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 28),
                                              _buildBackgroundControls(
                                                primary: primary,
                                                secondary: secondary,
                                                muted: muted,
                                                foreground: foreground,
                                                mutedForeground:
                                                    mutedForeground,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color foreground,
    required String semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Icon(icon, color: foreground, size: 22),
        ),
      ),
    ),
  );
}

  Widget _buildTransportButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color foreground,
    required String semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: foreground.withValues(alpha: 0.34),
              size: 34,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundControls({
    required Color primary,
    required Color secondary,
    required Color muted,
    required Color foreground,
    required Color mutedForeground,
  }) {
    final bool hasSelection = !_controller.backgroundSound.isNone;
    final bool canTemporarilyMute = hasSelection;
    final bool isActuallyEmitting =
        _controller.isBackgroundPlaying && !_controller.backgroundSound.isNone;
    final bool isLoadingBackground = !_controller.backgroundSound.isNone && !_controller.hasBackgroundAudio;
    final String backgroundStatusLabel;

    if (_controller.backgroundSound.isNone) {
      backgroundStatusLabel = 'SIN FONDO';
    } else if (isLoadingBackground) {
      backgroundStatusLabel =
          'CARGANDO ${_controller.backgroundSound.label.toUpperCase()}';
    } else if (isActuallyEmitting) {
      backgroundStatusLabel = _controller.backgroundSound.label.toUpperCase();
    } else {
      backgroundStatusLabel = 'SIN FONDO';
    }

    return Column(
      children: [
        Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: canTemporarilyMute ? _toggleBackground : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: canTemporarilyMute ? 0.05 : 0.03,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: canTemporarilyMute ? 0.05 : 0.03,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !hasSelection
                            ? mutedForeground.withValues(alpha: 0.6)
                            : (!_controller.isBackgroundPlaying
                                  ? mutedForeground
                                  : primary),
                        boxShadow:
                            !hasSelection || !_controller.isBackgroundPlaying
                            ? null
                            : [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.95),
                                  blurRadius: 10,
                                ),
                              ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      backgroundStatusLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: !hasSelection
                            ? mutedForeground
                            : (!_controller.isBackgroundPlaying
                                  ? foreground
                                  : primary),
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: SessionBackgroundSound.options
              .map(
                (sound) => _buildEnvironmentPill(
                  sound: sound,
                  isSelected: (isActuallyEmitting || isLoadingBackground)
                      ? _controller.backgroundSound.id == sound.id 
                      : sound.isNone,
                  onTap: sound.isAvailable
                      ? () => _changeBackgroundSound(sound)
                      : null,
                  primary: primary,
                  secondary: secondary,
                  muted: muted,
                  foreground: foreground,
                  mutedForeground: mutedForeground,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'PISO ACUSTICO',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: mutedForeground,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(_controller.backgroundVolume * 100).round()}%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: foreground.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
                  activeTrackColor: primary.withValues(alpha: 0.72),
                  thumbColor: primary,
                  overlayColor: primary.withValues(alpha: 0.12),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  value: _controller.backgroundVolume,
                  min: 0.1,
                  max: 0.85,
                  onChanged: _setBackgroundVolume,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnvironmentPill({
    required SessionBackgroundSound sound,
    required bool isSelected,
    required VoidCallback? onTap,
    required Color primary,
    required Color secondary,
    required Color muted,
    required Color foreground,
    required Color mutedForeground,
  }) {
    final bool isDisabled = !sound.isAvailable;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected ? primary.withValues(alpha: 0.14) : secondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isSelected
              ? primary.withValues(alpha: 0.32)
              : Colors.white.withValues(alpha: isDisabled ? 0.04 : 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  sound.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDisabled
                        ? mutedForeground.withValues(alpha: 0.5)
                        : (isSelected
                              ? foreground
                              : foreground.withValues(alpha: 0.82)),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '0:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    final String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}
