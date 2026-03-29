import 'package:app_pap_respiracion/features/sessions/data/firestore_audio_repository.dart';
import 'package:app_pap_respiracion/features/sessions/models/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreAudioRepository.parseSessionData', () {
    test('mapea un documento valido a AudioSession', () {
      final session = FirestoreAudioRepository.parseSessionData('session_1', {
        'title': 'Anclaje de trabajo profundo',
        'category': 'focus',
        'durationSeconds': 300,
        'audioSource': 'https://cdn.example.com/focus.mp3',
        'isPremium': false,
        'isOffline': false,
      });

      expect(session, isNotNull);
      expect(session!.id, 'session_1');
      expect(session.title, 'Anclaje de trabajo profundo');
      expect(session.category, SessionCategory.focus);
      expect(session.durationSeconds, 300);
      expect(session.audioSource, 'https://cdn.example.com/focus.mp3');
      expect(session.isPremium, isFalse);
      expect(session.isOffline, isFalse);
    });

    test('usa defaults seguros para flags opcionales', () {
      final session = FirestoreAudioRepository.parseSessionData('session_2', {
        'title': 'Desactivacion progresiva total',
        'category': 'sleep',
        'durationSeconds': 600,
        'audioSource': 'https://cdn.example.com/sleep.mp3',
      });

      expect(session, isNotNull);
      expect(session!.category, SessionCategory.sleep);
      expect(session.isPremium, isFalse);
      expect(session.isOffline, isFalse);
    });

    test('descarta categoria no reconocida', () {
      final session = FirestoreAudioRepository.parseSessionData('session_3', {
        'title': 'Categoria invalida',
        'category': 'unknown',
        'durationSeconds': 180,
        'audioSource': 'https://cdn.example.com/invalid.mp3',
      });

      expect(session, isNull);
    });

    test('descarta documentos mal formados', () {
      final session = FirestoreAudioRepository.parseSessionData('session_4', {
        'title': 'Sin duracion',
        'category': 'stress',
        'audioSource': 'https://cdn.example.com/stress.mp3',
      });

      expect(session, isNull);
    });
  });
}
