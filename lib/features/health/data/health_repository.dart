import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'models/health_log.dart';

class HealthRepository {
  HealthRepository._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const Stream<List<HealthLog>> _emptyLogsStream =
      Stream<List<HealthLog>>.empty();

  static String get currentUid => _auth.currentUser?.uid ?? '';

  static CollectionReference<Map<String, dynamic>>? get _logsCollection {
    final uid = currentUid;
    if (uid.isEmpty) return null;
    return _db.collection('users').doc(uid).collection('daily_logs');
  }

  static String _toDateId(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static List<String> _weeklyDateIds() {
    final today = DateTime.now();
    final baseDate = DateTime(today.year, today.month, today.day);
    return List<String>.generate(7, (index) {
      final date = baseDate.subtract(Duration(days: index));
      return _toDateId(date);
    });
  }

  /// Escribe o actualiza el registro diario de estado de ánimo.
  static Future<void> saveDailyCheckIn(int moodScore) async {
    final uid = currentUid;
    if (uid.isEmpty) {
      throw Exception('Sesión de usuario no disponible');
    }

    final date = DateTime.now();
    final docId = _toDateId(date);
    final logRef = _db
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(docId);

    final Map<String, dynamic> payload = {
      'mood_score': moodScore,
      'check_in_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    await logRef.set(payload, SetOptions(merge: true));
  }

  /// Observa reactivamente los últimos 7 registros de salud.
  static Stream<List<HealthLog>> watchWeeklyLogs() {
    final logCollection = _logsCollection;
    if (logCollection == null) return _emptyLogsStream;

    final dateIds = _weeklyDateIds();
    final controller = StreamController<List<HealthLog>>();
    final latestDocs = <String, DocumentSnapshot<Map<String, dynamic>>?>{};
    late final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
    subscriptions;

    void emitLogs() {
      final logs = dateIds
          .map((id) => latestDocs[id])
          .whereType<DocumentSnapshot<Map<String, dynamic>>>()
          .where((doc) => doc.exists)
          .map(HealthLog.fromFirestore)
          .toList()
        ..sort((a, b) => b.id.compareTo(a.id));

      controller.add(logs);
    }

    subscriptions = dateIds.map((id) {
      return logCollection
          .doc(id)
          .snapshots(includeMetadataChanges: true)
          .listen(
            (doc) {
              latestDocs[id] = doc;
              emitLogs();
            },
            onError: controller.addError,
          );
    }).toList();

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  /// Agrega feedback de una sesión al registro del día actual.
  static Future<void> addSessionFeedback(String sessionId, int score) async {
    final logCollection = _logsCollection;
    if (logCollection == null) return;

    try {
      final id = _toDateId(DateTime.now());
      final logRef = logCollection.doc(id);

      final Map<String, dynamic> feedback = {
        'session_id': sessionId,
        'feedback_score': score,
        'created_at': FieldValue.serverTimestamp(),
      };

      await logRef.set({
        'session_feedbacks': FieldValue.arrayUnion([feedback]),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthRepo] Error al guardar feedback: $e');
    }
  }

  /// Consulta puntual de los últimos 7 registros.
  static Future<List<HealthLog>> fetchWeeklyLogs() async {
    final logCollection = _logsCollection;
    if (logCollection == null) return [];

    try {
      final futures = _weeklyDateIds().map((id) => logCollection.doc(id).get());
      final docs = await Future.wait(futures);
      final logs = docs
          .where((doc) => doc.exists)
          .map(HealthLog.fromFirestore)
          .toList()
        ..sort((a, b) => b.id.compareTo(a.id));
      return logs;
    } catch (e) {
      return [];
    }
  }
}
