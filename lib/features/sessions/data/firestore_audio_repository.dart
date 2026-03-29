import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, visibleForTesting;
import '../models/audio_session.dart';

/// Repositorio de producción que lee la colección `sessions` en Cloud Firestore.
///
/// Estructura esperada de cada documento:
/// ```json
/// {
///   "title":           "Técnica 5-4-3-2-1",
///   "category":        "anxiety",        // valor del enum SessionCategory
///   "durationSeconds": 180,
///   "audioSource":     "https://...",    // URL HTTPS o "assets/audio/xxx.mp3"
///   "isPremium":       false,
///   "isOffline":       false
/// }
/// ```
/// El ID del documento Firestore se usa como `AudioSession.id`.
class FirestoreAudioRepository {
  FirestoreAudioRepository._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _sessionsCollection =>
      _db.collection('sessions');

  /// Stream en tiempo real de la colección `sessions`, ordenadas por título.
  /// Emite una lista vacía si la colección no tiene documentos.
  static Stream<List<AudioSession>> watchSessions() {
    return _sessionsCollection
        .orderBy('title')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _fromDoc(doc))
              .whereType<AudioSession>() // filtra documentos mal formados
              .toList(),
        );
  }

  /// Stream en tiempo real de sesiones destacadas para superficies resumidas.
  static Stream<List<AudioSession>> watchFeaturedSessions({int limit = 3}) {
    final safeLimit = limit < 1 ? 1 : limit;

    return _sessionsCollection
        .orderBy('title')
        .limit(safeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _fromDoc(doc))
              .whereType<AudioSession>()
              .toList(),
        );
  }

  /// Lectura puntual de sesiones para construir recomendaciones y accesos directos.
  static Future<List<AudioSession>> fetchSessions() async {
    try {
      final snapshot = await _sessionsCollection.orderBy('title').get();
      return snapshot.docs
          .map((doc) => _fromDoc(doc))
          .whereType<AudioSession>()
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[FirestoreRepo] fetchSessions fallo — $e');
      return [];
    }
  }

  /// Convierte un DocumentSnapshot a AudioSession.
  /// Devuelve null si algún campo obligatorio falta o tiene tipo incorrecto.
  static AudioSession? _fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return parseSessionData(doc.id, doc.data());
  }

  @visibleForTesting
  static AudioSession? parseSessionData(
    String documentId,
    Map<String, dynamic> data,
  ) {
    try {
      final title = data['title'] as String;
      final audioSource = data['audioSource'] as String;
      final durationSeconds = (data['durationSeconds'] as num).toInt();
      final categoryStr = data['category'] as String;
      final isPremium = (data['isPremium'] as bool?) ?? false;
      final isOffline = (data['isOffline'] as bool?) ?? false;
      final coverImageUrl =
          (data['coverImageUrl'] as String?) ?? (data['imageUrl'] as String?);

      // Mapea el string del campo `category` al enum tipado
      final category = _parseCategory(categoryStr);
      if (category == null) return null;

      return AudioSession(
        id: documentId,
        title: title,
        category: category,
        durationSeconds: durationSeconds,
        audioSource: audioSource,
        coverImageUrl: coverImageUrl,
        isPremium: isPremium,
        isOffline: isOffline,
      );
    } catch (e) {
      // Documento mal formado: lo ignoramos en lugar de romper el stream.
      if (kDebugMode) debugPrint('[FirestoreRepo] doc $documentId descartado — $e');
      return null;
    }
  }

  /// Parseo seguro del campo `category` → null si el valor no es reconocido.
  static SessionCategory? _parseCategory(String value) {
    switch (value.toLowerCase().trim()) {
      case 'anxiety':
        return SessionCategory.anxiety;
      case 'stress':
        return SessionCategory.stress;
      case 'sleep':
        return SessionCategory.sleep;
      case 'focus':
        return SessionCategory.focus;
      case 'mood':
        return SessionCategory.mood;
      default:
        return null;
    }
  }
}
