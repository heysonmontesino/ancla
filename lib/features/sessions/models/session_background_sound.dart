class SessionBackgroundSound {
  final String id;
  final String label;
  final String? assetPath;
  final double targetVolume;
  final bool isAvailable;

  const SessionBackgroundSound({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.targetVolume,
    this.isAvailable = true,
  });

  bool get isNone => assetPath == null;

  static const SessionBackgroundSound none = SessionBackgroundSound(
    id: 'none',
    label: 'Sin fondo',
    assetPath: null,
    targetVolume: 0.0,
    isAvailable: true,
  );

  static const SessionBackgroundSound brownNoise = SessionBackgroundSound(
    id: 'brown_noise',
    label: 'Ruido marron',
    assetPath: 'assets/audio/bg_brown_noise.mp3',
    targetVolume: 0.65,
  );

  static const SessionBackgroundSound rain = SessionBackgroundSound(
    id: 'rain',
    label: 'Lluvia',
    assetPath: 'assets/audio/bg_rain_soft.mp3',
    targetVolume: 0.65,
  );

  static const SessionBackgroundSound waves = SessionBackgroundSound(
    id: 'waves',
    label: 'Olas',
    assetPath: 'assets/audio/bg_ocean_waves.mp3',
    targetVolume: 0.65,
  );

  static const SessionBackgroundSound campfire = SessionBackgroundSound(
    id: 'campfire',
    label: 'Fogata',
    assetPath: 'assets/audio/bg_campfire.mp3',
    targetVolume: 0.65,
  );

  static const SessionBackgroundSound softAmbient = SessionBackgroundSound(
    id: 'soft_ambient',
    label: 'Ambiente suave',
    assetPath: 'assets/audio/bg_calm.wav',
    targetVolume: 0.65,
  );

  static const SessionBackgroundSound morningForest = SessionBackgroundSound(
    id: 'morning_forest',
    label: 'Bosque matutino',
    assetPath: 'assets/audio/ambience/morning_forest.wav',
    targetVolume: 0.65,
  );

  static const SessionBackgroundSound gentleStream = SessionBackgroundSound(
    id: 'gentle_stream',
    label: 'Arroyo suave',
    assetPath: 'assets/audio/ambience/gentle_stream.wav',
    targetVolume: 0.65,
  );

  static const SessionBackgroundSound pinkNoise = SessionBackgroundSound(
    id: 'pink_noise',
    label: 'Ruido rosa',
    assetPath: 'assets/audio/ambience/pink_noise.wav',
    targetVolume: 0.65,
  );

  static const SessionBackgroundSound forestWind = SessionBackgroundSound(
    id: 'forest_wind',
    label: 'Viento entre arboles',
    assetPath: 'assets/audio/ambience/forest_wind.wav',
    targetVolume: 0.65,
  );

  static const List<SessionBackgroundSound> options = [
    none,
    brownNoise,
    waves,
    rain,
    campfire,
    softAmbient,
    morningForest,
    gentleStream,
    pinkNoise,
    forestWind,
  ];
}
