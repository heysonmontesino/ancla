import '../models/audio_session.dart';

/// Repositorio mock que actúa como capa de datos provisional.
///
/// Arquitectura de streaming en la nube:
/// - isOffline: true  → audio embebido en el bundle (assets locales).
/// - isOffline: false → audio servido desde URL HTTPS (streaming).
///
/// En la implementación real, esta clase será reemplazada por un
/// RemoteAudioRepository que consuma la API REST / Firebase Storage.
class MockAudioRepository {
  static const List<AudioSession> sessions = [
    // ── ANSIEDAD ────────────────────────────────────────────────────────────
    AudioSession(
      id: 'session_1',
      title: 'Técnica 5-4-3-2-1',
      category: SessionCategory.anxiety,
      durationSeconds: 180,
      audioSource: 'assets/audio/guion_01.mp3',
      isPremium: false,
      isOffline: true,
    ),
    AudioSession(
      id: 'session_2',
      title: '¿Qué es la Ansiedad?',
      category: SessionCategory.anxiety,
      durationSeconds: 63,
      audioSource: 'assets/audio/guion_02.mp3',
      isPremium: false,
      isOffline: true,
    ),
    // ── ESTRÉS ──────────────────────────────────────────────────────────────
    AudioSession(
      id: 'session_3',
      title: 'Respiración Guiada 4-6',
      category: SessionCategory.stress,
      durationSeconds: 60,
      audioSource: 'assets/audio/guion_03.mp3',
      isPremium: false,
      isOffline: true,
    ),
    // ── SUEÑO — Sesión de streaming de prueba ────────────────────────────────
    AudioSession(
      id: 'session_4',
      title: 'Relajación para Dormir',
      category: SessionCategory.sleep,
      durationSeconds: 210, // ~3.5 min
      // URL pública HTTPS de SoundHelix para validar el pipeline de streaming
      audioSource:
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      isPremium: false,
      isOffline: false, // 🌐 Streaming desde la nube
    ),
  ];

  /// Devuelve todas las sesiones de una categoría concreta.
  static List<AudioSession> getSessionsByCategory(SessionCategory category) {
    return sessions.where((s) => s.category == category).toList();
  }

  /// Devuelve las categorías que tienen al menos una sesión disponible.
  static List<SessionCategory> get availableCategories {
    final seen = <SessionCategory>{};
    return sessions
        .where((s) => seen.add(s.category))
        .map((s) => s.category)
        .toList();
  }
}
