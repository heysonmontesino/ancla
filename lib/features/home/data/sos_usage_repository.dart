import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SosUsageSummary {
  const SosUsageSummary({
    required this.activationsLast24h,
    required this.activationsLast7d,
  });

  final int activationsLast24h;
  final int activationsLast7d;
}

class SosUsageRepository {
  SosUsageRepository._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const SosUsageSummary _emptySummary = SosUsageSummary(
    activationsLast24h: 0,
    activationsLast7d: 0,
  );

  static String _toDateId(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static CollectionReference<Map<String, dynamic>>? get _eventsCollection {
    final String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return null;
    }

    return _db.collection('users').doc(uid).collection('sos_events');
  }

  static Future<DocumentReference<Map<String, dynamic>>?>
  registerActivationStart() async {
    final CollectionReference<Map<String, dynamic>>? collection =
        _eventsCollection;
    if (collection == null) {
      if (kDebugMode) debugPrint('[SosUsageRepo] Sin sesión activa: no se registra entrada SOS.');
      return null;
    }

    final DateTime now = DateTime.now();
    final DocumentReference<Map<String, dynamic>> ref = collection.doc();

    try {
      await ref.set(<String, dynamic>{
        'event_date': _toDateId(now),
        'entered_at': Timestamp.fromDate(now),
        'recorded_at': FieldValue.serverTimestamp(),
        'completed_minimum_interaction': false,
        'duration_seconds': 0,
      });
      return ref;
    } catch (error) {
      if (kDebugMode) debugPrint('[SosUsageRepo] Error al registrar entrada SOS: $error');
      return null;
    }
  }

  static Future<void> registerActivationEnd({
    required DocumentReference<Map<String, dynamic>>? eventRef,
    required Duration duration,
    required bool completedMinimumInteraction,
  }) async {
    if (eventRef == null) {
      return;
    }

    try {
      await eventRef.set(<String, dynamic>{
        'completed_minimum_interaction': completedMinimumInteraction,
        'duration_seconds': duration.inSeconds,
        'completed_at': Timestamp.fromDate(DateTime.now()),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      if (kDebugMode) debugPrint('[SosUsageRepo] Error al cerrar evento SOS: $error');
    }
  }

  static Future<SosUsageSummary> fetchRecentSummary({DateTime? now}) async {
    final CollectionReference<Map<String, dynamic>>? collection =
        _eventsCollection;
    if (collection == null) {
      if (kDebugMode) {
        debugPrint(
          '[SosUsageRepo] Sin sesión activa: se devuelve resumen SOS vacío.',
        );
      }
      return _emptySummary;
    }

    final DateTime reference = now ?? DateTime.now();
    final Timestamp last24h = Timestamp.fromDate(
      reference.subtract(const Duration(hours: 24)),
    );
    final Timestamp last7d = Timestamp.fromDate(
      reference.subtract(const Duration(days: 7)),
    );

    try {
      final results = await Future.wait([
        collection.where('entered_at', isGreaterThanOrEqualTo: last24h).get(),
        collection.where('entered_at', isGreaterThanOrEqualTo: last7d).get(),
      ]);

      return SosUsageSummary(
        activationsLast24h: results[0].docs.length,
        activationsLast7d: results[1].docs.length,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('[SosUsageRepo] Error al consultar resumen SOS: $error');
      return _emptySummary;
    }
  }
}
