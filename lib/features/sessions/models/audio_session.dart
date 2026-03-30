enum SessionCategory { anxiety, stress, sleep, focus, mood }

/// Extensión para obtener el nombre de visualización en español
/// y los metadatos de diseño por categoría sin polucionar el enum.
extension SessionCategoryX on SessionCategory {
  String get displayName {
    switch (this) {
      case SessionCategory.anxiety:
        return 'Ansiedad';
      case SessionCategory.stress:
        return 'Estrés';
      case SessionCategory.sleep:
        return 'Sueño';
      case SessionCategory.focus:
        return 'Foco';
      case SessionCategory.mood:
        return 'Ánimo';
    }
  }

  String get subtitle {
    switch (this) {
      case SessionCategory.anxiety:
        return 'Regulación emocional y calma';
      case SessionCategory.stress:
        return 'Libera la tensión acumulada';
      case SessionCategory.sleep:
        return 'Transición hacia el descanso';
      case SessionCategory.focus:
        return 'Claridad mental y concentración';
      case SessionCategory.mood:
        return 'Bienestar y equilibrio emocional';
    }
  }

  /// Color de acento asociado a cada categoría
  int get colorValue {
    switch (this) {
      case SessionCategory.anxiety:
        return 0xFFEAF4EE; // Sage / verde suave
      case SessionCategory.stress:
        return 0xFFF5E6D3; // Tan cálido
      case SessionCategory.sleep:
        return 0xFFE8E3F2; // Lavanda noche
      case SessionCategory.focus:
        return 0xFFE3EBF2; // Azul muted
      case SessionCategory.mood:
        return 0xFFF2E8E3; // Melocotón suave
    }
  }

  /// Asset path para la carátula emocional generada por IA
  String get coverImagePath {
    switch (this) {
      case SessionCategory.anxiety:
        return 'assets/images/covers/anxiety.png';
      case SessionCategory.stress:
        return 'assets/images/covers/stress.png';
      case SessionCategory.sleep:
        return 'assets/images/covers/sleep.png';
      case SessionCategory.focus:
        return 'assets/images/covers/focus.png';
      case SessionCategory.mood:
        return 'assets/images/covers/mood.png';
    }
  }
}

class AudioSession {
  final String id;
  final String title;
  final SessionCategory category;
  final int durationSeconds;
  final String audioSource;

  /// URL opcional de la carátula en la nube.
  /// Si es null, se usa una representación visual de respaldo.
  final String? coverUrl;

  /// true → contenido exclusivo de suscripción premium.
  final bool isPremium;

  /// true → el audio está embebido en el bundle (asset local).
  /// false → el audio se sirve vía streaming desde la nube.
  final bool isOffline;

  const AudioSession({
    required this.id,
    required this.title,
    required this.category,
    required this.durationSeconds,
    required this.audioSource,
    String? coverUrl,
    String? coverImageUrl,
    this.isPremium = false,
    this.isOffline = false,
  }) : coverUrl = coverUrl ?? coverImageUrl;

  /// Compatibilidad con SessionPlayerScreen: devuelve el displayName
  /// de la categoría (antes llamado categoryDisplay).
  String get categoryDisplay => category.displayName;

  /// Compatibilidad hacia atras con superficies que aun leen `coverImageUrl`.
  String? get coverImageUrl => coverUrl;

  String? get normalizedCoverUrl {
    final value = coverUrl?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
