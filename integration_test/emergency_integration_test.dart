import 'dart:async';

import 'package:app_pap_respiracion/features/home/emergency_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _FakeJustAudioPlatform fakePlatform;

  setUpAll(() {
    fakePlatform = _FakeJustAudioPlatform();
    JustAudioPlatform.instance = fakePlatform;
  });

  setUp(() {
    fakePlatform.reset();
  });

  testWidgets('SOS abre, renderiza el flujo base y permite volver', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _EmergencyTestHost()));

    expect(find.text('Pantalla base'), findsOneWidget);

    await tester.tap(find.text('Abrir SOS'));
    await tester.pumpAndSettle();

    expect(find.byType(EmergencyScreen), findsOneWidget);
    expect(find.text('Respirar'), findsOneWidget);
    expect(find.text('Inhala mientras el círculo crece'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla base'), findsOneWidget);
    expect(find.byType(EmergencyScreen), findsNothing);
  });
}

class _EmergencyTestHost extends StatelessWidget {
  const _EmergencyTestHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pantalla base'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EmergencyScreen()),
                );
              },
              child: const Text('Abrir SOS'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakeJustAudioPlatform extends JustAudioPlatform {
  final Map<String, _FakeAudioPlayerPlatform> _playersById = {};

  void reset() {
    for (final player in _playersById.values) {
      player.disposeInternal();
    }
    _playersById.clear();
  }

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = _FakeAudioPlayerPlatform(request.id);
    _playersById[request.id] = player;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
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

class _FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  _FakeAudioPlayerPlatform(super.id);

  final StreamController<PlaybackEventMessage> _playbackController =
      StreamController<PlaybackEventMessage>.broadcast();
  final StreamController<PlayerDataMessage> _dataController =
      StreamController<PlayerDataMessage>.broadcast();

  Duration position = Duration.zero;
  Duration? duration = const Duration(minutes: 2);
  bool playing = false;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      _playbackController.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream =>
      _dataController.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _emitPlaybackEvent();
    return LoadResponse(duration: duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    playing = true;
    _dataController.add(PlayerDataMessage(playing: true));
    _emitPlaybackEvent();
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
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

  void disposeInternal() {
    if (!_playbackController.isClosed) {
      _playbackController.close();
    }
    if (!_dataController.isClosed) {
      _dataController.close();
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
