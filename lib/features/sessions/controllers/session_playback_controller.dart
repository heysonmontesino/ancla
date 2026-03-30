import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audio_session.dart';
import '../models/session_background_sound.dart';

class SessionPlaybackController extends BaseAudioHandler
    with SeekHandler, ChangeNotifier {
  static const String _privateMediaTitle = 'Sesion en reproduccion';
  static const String _privateMediaSubtitle = 'Audio activo';
  static const String _privateMediaArtist = 'PAP Respiracion';

  SessionPlaybackController._() {
    _bindPlayerListeners();
  }

  static final SessionPlaybackController instance =
      SessionPlaybackController._();

  static const double _initialBackgroundVolume = 0.65;
  static const String _premiumRequiredMessage =
      'Esta sesión es exclusiva para usuarios premium.';

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer _bgPlayer = AudioPlayer();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<PlayerState>? _backgroundStateSubscription;

  AudioSession? _currentSession;
  bool _isClosing = false;
  bool _isSessionActive = false;
  bool _isVoiceCompleted = false;
  bool _isVoicePlaying = false;
  bool _isBackgroundPlaying = false;
  bool _isReady = false;
  bool _hasBackgroundAudio = false;
  bool _isBackgroundOff = false;
  bool _hasLoggedStartForCurrentSession = false;
  int _backgroundLoadRequestId = 0;
  double _backgroundVolume = _initialBackgroundVolume;
  SessionBackgroundSound _backgroundSound = SessionBackgroundSound.none;
  String? _loadError;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  AudioSession? get currentSession => _currentSession;
  bool get hasCurrentSession => _currentSession != null;
  bool get isClosing => _isClosing;
  bool get isSessionActive => _isSessionActive;
  bool get isVoiceCompleted => _isVoiceCompleted;
  bool get isVoicePlaying => _isVoicePlaying;
  bool get isBackgroundPlaying => _isBackgroundPlaying;
  bool get isReady => _isReady;
  bool get hasBackgroundAudio => _hasBackgroundAudio;
  bool get isBackgroundOff => _isBackgroundOff;
  double get backgroundVolume => _backgroundVolume;
  SessionBackgroundSound get backgroundSound => _backgroundSound;
  String? get loadError => _loadError;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isPlaybackActive => _isVoicePlaying;

  Future<void> openSession(AudioSession session) async {
    if (session.isPremium && !await _currentUserIsPremium()) {
      await _stopPlayers(resetCompletion: false);
      _isClosing = false;
      _currentSession = session;
      mediaItem.add(_buildMediaItem(session));
      _resetSessionState();
      _loadError = _premiumRequiredMessage;
      _broadcastPlaybackState();
      notifyListeners();
      return;
    }

    final bool isSameSession = _currentSession?.id == session.id;
    if (isSameSession && (_isReady || isPlaybackActive || _loadError == null)) {
      return;
    }

    _isClosing = false;
    _currentSession = session;
    mediaItem.add(_buildMediaItem(session));
    await _stopPlayers(resetCompletion: false);
    _resetSessionState();
    _hasLoggedStartForCurrentSession = false;
    _broadcastPlaybackState();
    notifyListeners();

    try {
      await _initVoiceTrack(session);

      try {
        _hasBackgroundAudio = await _initBackgroundTrack(autoplay: false);
      } catch (e) {
        if (kDebugMode) debugPrint('Optional background audio unavailable: $e');
        _hasBackgroundAudio = false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading audio: $e');
      _isReady = false;
      _loadError = 'Este audio no esta disponible en el dispositivo.';
    }

    _broadcastPlaybackState();
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (isPlaybackActive) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> play() async {
    if (_isClosing || _currentSession == null) return;
    if (_currentSession!.isPremium && !await _currentUserIsPremium()) {
      _isReady = false;
      _loadError = _premiumRequiredMessage;
      _broadcastPlaybackState();
      notifyListeners();
      throw const SessionPlaybackException(_premiumRequiredMessage);
    }
    if (!_isReady) {
      throw const SessionPlaybackException(
        'Este audio no esta disponible en este momento.',
      );
    }

    if (_isVoiceCompleted) {
      await _resumeBackgroundIfNeeded();
      _broadcastPlaybackState();
      notifyListeners();
      return;
    }

    await _player.play();
    if (!_hasLoggedStartForCurrentSession) {
      _hasLoggedStartForCurrentSession = true;
      unawaited(
        FirebaseAnalytics.instance.logEvent(
          name: 'session_started',
          parameters: {
            'session_id': _currentSession?.id ?? 'unknown',
            'session_title': _currentSession?.title ?? 'Untitled',
            'category': _currentSession?.category.name ?? 'none',
          },
        ),
      );
    }
    await _resumeBackgroundIfNeeded();
    _broadcastPlaybackState();
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    if (_isClosing) return;
    // Pausa total (comportamiento estandar del sistema)
    if (_player.playing) await _player.pause();
    if (_bgPlayer.playing) await _bgPlayer.pause();
    _broadcastPlaybackState();
    notifyListeners();
  }

  /// Pausa solo la voz, permitiendo que el ambiente siga sonando.
  Future<void> pauseVoice({bool keepBackground = true}) async {
    if (_isClosing) return;
    if (_player.playing) await _player.pause();
    if (!keepBackground && _bgPlayer.playing) await _bgPlayer.pause();
    _broadcastPlaybackState();
    notifyListeners();
  }

  Future<void> closeSession() async {
    if (_isClosing) return;
    _isClosing = true;
    notifyListeners();
    await stop();
  }

  @override
  Future<void> stop() async {
    await _stopPlayers(resetCompletion: true);
    _currentSession = null;
    _resetSessionState();
    mediaItem.add(null);
    _broadcastPlaybackState();
    _isClosing = false;
    notifyListeners();
  }

  Future<void> seekVoice(Duration position) async {
    if (_isClosing || _currentSession == null) return;
    final Duration clamped = position > _duration ? _duration : position;
    await _player.seek(clamped);
    if (_isVoiceCompleted && clamped < _duration) {
      _isVoiceCompleted = false;
      _syncSessionFlags();
      _broadcastPlaybackState();
      notifyListeners();
    }
  }

  @override
  Future<void> seek(Duration position) => seekVoice(position);

  Future<bool> toggleBackground() async {
    if (_isClosing || _backgroundSound.isNone) return true;
    
    // Si NO esta sonando (esta en pausa o apagado por el usuario), lo encendemos
    if (!_isBackgroundPlaying) {
      if (!_hasBackgroundAudio) {
        final bool loaded = await _loadBackgroundSound(
          _backgroundSound,
          autoplay: true,
          requestId: _backgroundLoadRequestId,
        );
        _hasBackgroundAudio = loaded;
        _isBackgroundOff = !loaded;
      } else {
        await _bgPlayer.setVolume(_backgroundVolume);
        await _bgPlayer.play();
        _isBackgroundOff = false;
      }
    } else {
      // Si SI esta sonando, lo apagamos/pausamos
      await _pauseBackgroundAudio();
      _isBackgroundOff = true;
    }

    _broadcastPlaybackState();
    notifyListeners();
    return true;
  }

  Future<bool> changeBackgroundSound(SessionBackgroundSound sound) async {
    if (_isClosing || _backgroundSound.id == sound.id || !sound.isAvailable) {
      return true;
    }

    final int requestId = ++_backgroundLoadRequestId;
    final SessionBackgroundSound previousSound = _backgroundSound;
    final bool shouldResume = !_isBackgroundOff;

    _backgroundSound = sound;
    _isBackgroundOff = false;
    _hasBackgroundAudio = !sound.isNone;
    _broadcastPlaybackState();
    notifyListeners();

    if (sound.isNone) {
      await _bgPlayer.stop();
      if (requestId == _backgroundLoadRequestId) {
        _hasBackgroundAudio = false;
        _broadcastPlaybackState();
        notifyListeners();
      }
      return true;
    }

    final bool loaded = await _loadBackgroundSound(
      sound,
      autoplay: shouldResume,
      requestId: requestId,
    );

    if (requestId != _backgroundLoadRequestId) {
      return true;
    }

    if (!loaded) {
      if (!previousSound.isNone) {
        await _loadBackgroundSound(
          previousSound,
          autoplay: shouldResume,
          requestId: requestId,
        );
      }
      _backgroundSound = previousSound;
      _hasBackgroundAudio = !previousSound.isNone;
      _broadcastPlaybackState();
      notifyListeners();
      return false;
    }

    _hasBackgroundAudio = true;
    _isBackgroundOff = false;
    _broadcastPlaybackState();
    notifyListeners();
    return true;
  }

  Future<void> setBackgroundVolume(double value) async {
    if (_isClosing) return;
    _backgroundVolume = value.clamp(0.1, 0.85);
    if (_hasBackgroundAudio && !_isBackgroundOff) {
      await _bgPlayer.setVolume(_backgroundVolume);
    }
    _broadcastPlaybackState();
    notifyListeners();
  }

  void _bindPlayerListeners() {
    // Cancel existing subscriptions before rebinding to prevent duplicate
    // listeners and subscription leaks if this method is called more than once.
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();

    _durationSubscription = _player.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      _broadcastPlaybackState();
      notifyListeners();
    });

    _positionSubscription = _player.positionStream.listen((p) {
      _position = p;
      _broadcastPlaybackState();
      notifyListeners();
    });

    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_isVoiceCompleted) return;
        unawaited(_handleVoiceCompletion());
        return;
      }

      _isVoicePlaying = state.playing;
      if (state.playing) {
        _isVoiceCompleted = false;
      }
      _syncSessionFlags();
      _broadcastPlaybackState();
      notifyListeners();
    });

    _bindBackgroundStateListener();
  }

  void _bindBackgroundStateListener() {
    _backgroundStateSubscription?.cancel();
    _backgroundStateSubscription = _bgPlayer.playerStateStream.listen((state) {
      _isBackgroundPlaying = state.playing;
      _syncSessionFlags();
      _broadcastPlaybackState();
      notifyListeners();
    });
  }

  void _syncSessionFlags() {
    _isSessionActive =
        !_isClosing &&
        (_isVoicePlaying || _isBackgroundPlaying || _isVoiceCompleted);
  }

  void _resetSessionState() {
    _isSessionActive = false;
    _isVoiceCompleted = false;
    _isVoicePlaying = false;
    _isBackgroundPlaying = false;
    _isReady = false;
    _hasBackgroundAudio = false;
    _isBackgroundOff = false;
    _backgroundLoadRequestId = 0;
    _backgroundVolume = _initialBackgroundVolume;
    _backgroundSound = SessionBackgroundSound.none;
    _loadError = null;
    _duration = Duration.zero;
    _position = Duration.zero;
  }

  MediaItem _buildMediaItem(AudioSession session) {
    return MediaItem(
      id: session.id,
      title: _privateMediaTitle,
      album: _privateMediaSubtitle,
      artist: _privateMediaArtist,
      displayTitle: _privateMediaTitle,
      displaySubtitle: _privateMediaSubtitle,
      duration: Duration(seconds: session.durationSeconds),
    );
  }

  Future<void> _initVoiceTrack(AudioSession session) async {
    final String source = session.audioSource;
    if (source.startsWith('assets/')) {
      await _player.setAudioSource(AudioSource.asset(source));
    } else {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(source)));
    }
    await _player.setVolume(_voiceVolumeForSource(source));
    _isReady = true;
    _loadError = null;
  }

  Future<bool> _initBackgroundTrack({required bool autoplay}) async {
    return _loadBackgroundSound(_backgroundSound, autoplay: autoplay);
  }

  Future<bool> _loadBackgroundSound(
    SessionBackgroundSound sound, {
    required bool autoplay,
    int? requestId,
    bool didRetryWithFreshPlayer = false,
  }) async {
    if (_isClosing) return false;
    if (sound.isNone) {
      await _bgPlayer.stop();
      return true;
    }

    final String? assetPath = sound.assetPath;
    if (assetPath == null || _currentSession == null) {
      return false;
    }

    try {
      await _bgPlayer.stop();
      await _bgPlayer.setAsset(assetPath);
      await _bgPlayer.setLoopMode(LoopMode.one);
      await _bgPlayer.setVolume(_isBackgroundOff ? 0.0 : _backgroundVolume);
      if (requestId != null && requestId != _backgroundLoadRequestId) {
        return false;
      }
      if (autoplay && !_isBackgroundOff) {
        await _bgPlayer.play();
      }
      return true;
    } catch (e) {
      if (!didRetryWithFreshPlayer && !_isClosing) {
        await _recreateBackgroundPlayer();
        return _loadBackgroundSound(
          sound,
          autoplay: autoplay,
          requestId: requestId,
          didRetryWithFreshPlayer: true,
        );
      }
      if (kDebugMode) debugPrint('Optional background audio unavailable (${sound.id}): $e');
      return false;
    }
  }

  Future<void> _recreateBackgroundPlayer() async {
    _backgroundStateSubscription?.cancel();
    await _bgPlayer.stop();
    await _bgPlayer.dispose();
    _bgPlayer = AudioPlayer();
    _bindBackgroundStateListener();
  }

  Future<void> _pauseBackgroundAudio() async {
    if (_isClosing || !_hasBackgroundAudio || !_bgPlayer.playing) return;
    await _bgPlayer.pause();
  }

  Future<void> _resumeBackgroundIfNeeded() async {
    if (_isClosing || _isBackgroundOff || _backgroundSound.isNone) return;

    if (!_hasBackgroundAudio) {
      _hasBackgroundAudio = await _loadBackgroundSound(
        _backgroundSound,
        autoplay: true,
        requestId: _backgroundLoadRequestId,
      );
      _broadcastPlaybackState();
      notifyListeners();
      return;
    }

    await _bgPlayer.setVolume(_backgroundVolume);
    if (!_bgPlayer.playing) {
      await _bgPlayer.play();
    }
  }

  Future<void> _handleVoiceCompletion() async {
    if (_isClosing || _isVoiceCompleted) return;
    _isVoiceCompleted = true;
    _isVoicePlaying = false;
    if (_duration > Duration.zero) {
      _position = _duration;
    }
    unawaited(
      FirebaseAnalytics.instance.logEvent(
        name: 'session_completed',
        parameters: {
          'session_id': _currentSession?.id ?? 'unknown',
          'session_title': _currentSession?.title ?? 'Untitled',
          'category': _currentSession?.category.name ?? 'none',
        },
      ),
    );
    _syncSessionFlags();
    _broadcastPlaybackState();
    notifyListeners();
  }

  Future<void> _stopPlayers({required bool resetCompletion}) async {
    if (_player.playing || _player.processingState != ProcessingState.idle) {
      await _player.stop();
    }
    if (_bgPlayer.playing ||
        _bgPlayer.processingState != ProcessingState.idle) {
      await _bgPlayer.stop();
    }
    if (resetCompletion) {
      _isVoiceCompleted = false;
    }
  }

  double _voiceVolumeForSource(String source) {
    return source.startsWith('assets/') ? 1.0 : 1.0;
  }

  Future<bool> _currentUserIsPremium() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    try {
      final IdTokenResult tokenResult = await user.getIdTokenResult();
      final dynamic claim = tokenResult.claims?['isPremium'];

      if (claim is bool) {
        return claim;
      }
      if (claim is num) {
        return claim != 0;
      }
      if (claim is String) {
        return claim.toLowerCase() == 'true';
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Error resolving premium claim: $error');
      return false;
    }

    return false;
  }

  void _broadcastPlaybackState() {
    final bool playing = _isVoicePlaying || _isBackgroundPlaying;
    final AudioProcessingState processingState;
    if (_currentSession == null) {
      processingState = AudioProcessingState.idle;
    } else if (_loadError != null) {
      processingState = AudioProcessingState.error;
    } else if (_player.processingState == ProcessingState.loading ||
        _player.processingState == ProcessingState.buffering) {
      processingState = AudioProcessingState.buffering;
    } else if (_player.processingState == ProcessingState.completed &&
        !_isBackgroundPlaying) {
      processingState = AudioProcessingState.completed;
    } else {
      processingState = AudioProcessingState.ready;
    }

    playbackState.add(
      PlaybackState(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0],
        processingState: processingState,
        playing: playing,
        updatePosition: _position,
        bufferedPosition: _position,
        speed: 1.0,
      ),
    );
  }
}

class SessionPlaybackException implements Exception {
  const SessionPlaybackException(this.message);

  final String message;

  @override
  String toString() => message;
}
