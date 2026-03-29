import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:app_pap_respiracion/features/sessions/data/mock_audio_repository.dart';
import 'package:app_pap_respiracion/features/sessions/models/audio_session.dart';
import 'package:app_pap_respiracion/features/sessions/ui/session_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_base;
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeJustAudioPlatform fakePlatform;
  const fakeTempDir = '/tmp/app_pap_respiracion_test_cache';
  const ahemFontPath =
      '/opt/homebrew/share/flutter/packages/flutter_tools/static/Ahem.ttf';
  const fakeGoogleFontAssets = <String, String>{
    'test/fonts/Inter-SemiBold.ttf': ahemFontPath,
    'test/fonts/Inter-Bold.ttf': ahemFontPath,
    'test/fonts/PlayfairDisplay-Bold.ttf': ahemFontPath,
  };
  final session = MockAudioRepository.sessions.firstWhere(
    (item) => item.id == 'session_2',
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    fakePlatform = _FakeJustAudioPlatform();
    JustAudioPlatform.instance = fakePlatform;
    Directory(fakeTempDir).createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(fakeTempDir);
    google_fonts_base.assetManifest = _StaticAssetManifest(
      fakeGoogleFontAssets.keys.toList(growable: false),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          if (message == null) return null;
          final assetKey = Uri.decodeFull(
            utf8.decode(message.buffer.asUint8List()),
          );
          final file = File(fakeGoogleFontAssets[assetKey] ?? assetKey);
          if (!file.existsSync()) return null;
          final bytes = file.readAsBytesSync();
          return ByteData.sublistView(bytes);
        });
  });

  setUp(() {
    fakePlatform.reset();
  });

  testWidgets('Reproduccion basica: play deja el player principal en playing', (
    tester,
  ) async {
    await _pumpPlayerScreen(tester, session: session);

    final mainPlayer = await _waitForPlayer(tester, fakePlatform, session.audioSource);

    expect(mainPlayer.playing, isFalse);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await _pumpAsync(tester);

    expect(mainPlayer.playing, isTrue);
    expect(mainPlayer.playCallCount, 1);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });

  testWidgets('Toggle del fondo: cambia volumen sin detener el player principal', (
    tester,
  ) async {
    await _pumpPlayerScreen(tester, session: session);

    final mainPlayer = await _waitForPlayer(tester, fakePlatform, session.audioSource);
    final bgPlayer = await _waitForPlayer(tester, fakePlatform, 'assets/audio/bg_calm.wav');

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await _pumpAsync(tester);

    expect(mainPlayer.playing, isTrue);
    expect(bgPlayer.volume, closeTo(0.15, 0.0001));

    await tester.tap(find.text('Fondo activo'));
    await _pumpAsync(tester);

    expect(bgPlayer.volume, 0.0);
    expect(mainPlayer.playing, isTrue);
    expect(find.text('Fondo apagado'), findsOneWidget);

    await tester.tap(find.text('Fondo apagado'));
    await _pumpAsync(tester);

    expect(bgPlayer.volume, closeTo(0.15, 0.0001));
    expect(mainPlayer.playing, isTrue);
    expect(find.text('Fondo activo'), findsOneWidget);
  });

  testWidgets('Completion behavior: pausa, resetea posicion y detiene fondo', (
    tester,
  ) async {
    await _pumpPlayerScreen(tester, session: session);

    final mainPlayer = await _waitForPlayer(tester, fakePlatform, session.audioSource);
    final bgPlayer = await _waitForPlayer(tester, fakePlatform, 'assets/audio/bg_calm.wav');

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await _pumpAsync(tester);

    mainPlayer.simulatePosition(const Duration(seconds: 20));
    bgPlayer.simulatePosition(const Duration(seconds: 12));
    await _pumpAsync(tester);

    expect(find.text('00:20'), findsOneWidget);

    mainPlayer.simulateCompleted();
    await _pumpAsync(tester);

    expect(mainPlayer.pauseCallCount, 1);
    expect(bgPlayer.pauseCallCount, 1);
    expect(mainPlayer.position, Duration.zero);
    expect(bgPlayer.position, Duration.zero);
    expect(mainPlayer.playing, isFalse);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
  });

  testWidgets('Replay: despues de completion vuelve a iniciar desde cero', (
    tester,
  ) async {
    await _pumpPlayerScreen(tester, session: session);

    final mainPlayer = await _waitForPlayer(tester, fakePlatform, session.audioSource);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await _pumpAsync(tester);

    mainPlayer.simulatePosition(const Duration(seconds: 18));
    await _pumpAsync(tester);
    mainPlayer.simulateCompleted();
    await _pumpAsync(tester);

    expect(mainPlayer.position, Duration.zero);
    expect(mainPlayer.playing, isFalse);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await _pumpAsync(tester);

    expect(mainPlayer.playCallCount, 2);
    expect(mainPlayer.position, Duration.zero);
    expect(mainPlayer.playing, isTrue);
  });

  testWidgets('Fondo no disponible: el player principal sigue y el boton no aparece', (
    tester,
  ) async {
    fakePlatform.reset(
      failAssetPaths: const {'assets/audio/bg_calm.wav'},
    );

    await _pumpPlayerScreen(tester, session: session, resetPlatform: false);

    final mainPlayer = await _waitForPlayer(tester, fakePlatform, session.audioSource);

    expect(find.text('Fondo activo'), findsNothing);
    expect(find.text('Fondo apagado'), findsNothing);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await _pumpAsync(tester);

    expect(mainPlayer.playing, isTrue);
    expect(mainPlayer.playCallCount, 1);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });
}

Future<_FakeAudioPlayerPlatform> _waitForPlayer(
  WidgetTester tester,
  _FakeJustAudioPlatform platform,
  String assetPath,
) async {
  for (var i = 0; i < 40; i++) {
    final player = platform.playerForAsset(assetPath);
    if (player != null) return player;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    });
    await tester.pump(const Duration(milliseconds: 25));
  }

  throw StateError(
    'Player for $assetPath not loaded. Loaded assets: ${platform.loadedAssets}',
  );
}

Future<void> _pumpAsync(WidgetTester tester, {int cycles = 3}) async {
  for (var i = 0; i < cycles; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    });
    await tester.pump(const Duration(milliseconds: 25));
  }
}

Future<void> _pumpPlayerScreen(
  WidgetTester tester, {
  required AudioSession session,
  bool resetPlatform = true,
}) async {
  if (resetPlatform) {
    final platform = JustAudioPlatform.instance as _FakeJustAudioPlatform;
    platform.reset();
  }

  tester.view.physicalSize = const Size(1440, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: SessionPlayerScreen(session: session),
    ),
  );

  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump(const Duration(milliseconds: 10));
  }

  final exception = tester.takeException();
  if (exception != null) {
    throw StateError('Pump failed: $exception');
  }
}

class _FakeJustAudioPlatform extends JustAudioPlatform {
  final Map<String, _FakeAudioPlayerPlatform> _playersById = {};
  Set<String> _failAssetPaths = <String>{};

  List<String?> get loadedAssets => _playersById.values
      .map((player) => player.loadedAssetPath)
      .toList(growable: false);

  void reset({Set<String> failAssetPaths = const <String>{}}) {
    for (final player in _playersById.values) {
      player.disposeInternal();
    }
    _playersById.clear();
    _failAssetPaths = failAssetPaths;
  }

  _FakeAudioPlayerPlatform? playerForAsset(String assetPath) {
    for (final player in _playersById.values) {
      final loadedAssetPath = player.loadedAssetPath;
      if (loadedAssetPath == null) continue;
      if (loadedAssetPath == assetPath) return player;
      if (loadedAssetPath.endsWith('/$assetPath')) return player;
      if (loadedAssetPath.endsWith(assetPath)) return player;
    }
    return null;
  }

  Duration _durationForAsset(String? assetPath) {
    final match = MockAudioRepository.sessions
        .where((session) => session.audioSource == assetPath)
        .toList();
    if (match.isNotEmpty) {
      return Duration(seconds: match.first.durationSeconds);
    }
    if (assetPath == 'assets/audio/bg_calm.wav') {
      return const Duration(minutes: 5);
    }
    return const Duration(minutes: 1);
  }

  bool shouldFail(String? assetPath) => assetPath != null && _failAssetPaths.contains(assetPath);

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = _FakeAudioPlayerPlatform(
      id: request.id,
      owner: this,
    );
    _playersById[request.id] = player;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    _playersById.remove(request.id)?.disposeInternal();
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    reset();
    return DisposeAllPlayersResponse();
  }
}

class _StaticAssetManifest implements AssetManifest {
  const _StaticAssetManifest(this.assets);

  final List<String> assets;

  @override
  List<String> listAssets() => assets;

  @override
  List<AssetMetadata>? getAssetVariants(String key) {
    if (!assets.contains(key)) return null;
    return <AssetMetadata>[
      AssetMetadata(
        key: key,
        targetDevicePixelRatio: null,
        main: true,
      ),
    ];
  }
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

class _FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  _FakeAudioPlayerPlatform({
    required String id,
    required this.owner,
  }) : super(id);

  final _FakeJustAudioPlatform owner;
  final StreamController<PlaybackEventMessage> _playbackController =
      StreamController<PlaybackEventMessage>.broadcast();
  final StreamController<PlayerDataMessage> _dataController =
      StreamController<PlayerDataMessage>.broadcast();

  String? loadedAssetPath;
  Duration? duration;
  Duration position = Duration.zero;
  bool playing = false;
  double volume = 1.0;
  int playCallCount = 0;
  int pauseCallCount = 0;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      _playbackController.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream =>
      _dataController.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    loadedAssetPath = _extractAssetPath(request.audioSourceMessage);
    if (owner.shouldFail(loadedAssetPath)) {
      throw PlatformException(
        code: 'load_failed',
        message: 'Unable to load $loadedAssetPath',
      );
    }

    duration = owner._durationForAsset(loadedAssetPath);
    position = request.initialPosition ?? Duration.zero;
    _emitPlaybackEvent();
    return LoadResponse(duration: duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    playCallCount += 1;
    playing = true;
    _dataController.add(PlayerDataMessage(playing: true));
    _emitPlaybackEvent();
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    pauseCallCount += 1;
    playing = false;
    _dataController.add(PlayerDataMessage(playing: false));
    _emitPlaybackEvent();
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    position = request.position ?? Duration.zero;
    _emitPlaybackEvent();
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    volume = request.volume;
    _dataController.add(PlayerDataMessage(volume: volume));
    return SetVolumeResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    return SetSpeedResponse();
  }

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async {
    return SetPitchResponse();
  }

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async {
    return SetSkipSilenceResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async {
    return SetShuffleModeResponse();
  }

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
      setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async {
    return SetAutomaticallyWaitsToMinimizeStallingResponse();
  }

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async {
    return SetAndroidAudioAttributesResponse();
  }

  void simulatePosition(Duration nextPosition) {
    position = nextPosition;
    _emitPlaybackEvent();
  }

  void simulateCompleted() {
    position = duration ?? position;
    _emitPlaybackEvent(processingState: ProcessingStateMessage.completed);
  }

  void disposeInternal() {
    if (!_playbackController.isClosed) {
      _playbackController.close();
    }
    if (!_dataController.isClosed) {
      _dataController.close();
    }
  }

  String? _extractAssetPath(AudioSourceMessage message) {
    switch (message) {
      case UriAudioSourceMessage():
        final uri = Uri.parse(message.uri);
        if (uri.scheme == 'asset') {
          final path = uri.path;
          return path.startsWith('/') ? path.substring(1) : path;
        }
        if (uri.scheme == 'file') {
          final path = uri.path;
          final marker = '/assets/';
          final markerIndex = path.lastIndexOf(marker);
          if (markerIndex != -1) {
            return path.substring(markerIndex + 1);
          }
        }
        return message.uri;
      case ConcatenatingAudioSourceMessage():
        if (message.children.isEmpty) return null;
        return _extractAssetPath(message.children.first);
      case ClippingAudioSourceMessage():
        return _extractAssetPath(message.child);
      case LoopingAudioSourceMessage():
        return _extractAssetPath(message.child);
      default:
        return null;
    }
  }

  void _emitPlaybackEvent({
    ProcessingStateMessage processingState = ProcessingStateMessage.ready,
  }) {
    _playbackController.add(
      PlaybackEventMessage(
        processingState: processingState,
        updateTime: DateTime.now(),
        updatePosition: position,
        bufferedPosition: duration ?? position,
        duration: duration,
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      ),
    );
  }
}
