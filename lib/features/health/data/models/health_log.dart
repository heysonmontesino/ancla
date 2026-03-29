import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Valores constantes para la escala emocional clínica (-1, 0, 1).
class MoodScale {
  MoodScale._();
  static const int bad = -1;
  static const int neutral = 0;
  static const int good = 1;
  static const int unknown = -99;
}

class SessionFeedback {
  final String sessionId;
  final int score;
  final DateTime createdAt;

  SessionFeedback({
    required this.sessionId,
    required this.score,
    required this.createdAt,
  });

  factory SessionFeedback.fromMap(Map<String, dynamic> map) {
    final timestamp = map['created_at'] as Timestamp?;
    return SessionFeedback(
      sessionId: map['session_id'] as String,
      score: map['feedback_score'] as int,
      createdAt: (timestamp ?? Timestamp.now()).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'feedback_score': score,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}

class HealthLog {
  final String id; // FORMAT: YYYY-MM-DD
  final int moodScore;
  final DateTime checkInAt;
  final String? note;
  final List<SessionFeedback> sessionFeedbacks;

  HealthLog({
    required this.id,
    required this.moodScore,
    required this.checkInAt,
    this.note,
    required this.sessionFeedbacks,
  });

  factory HealthLog.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final timestamp = data['check_in_at'] as Timestamp?;
      return HealthLog(
        id: doc.id,
        moodScore: (data['mood_score'] as num?)?.toInt() ?? MoodScale.unknown,
        checkInAt: (timestamp ?? Timestamp.now()).toDate(),
        note: data['note'] as String?,
        sessionFeedbacks: (data['session_feedbacks'] as List? ?? [])
            .map((f) => SessionFeedback.fromMap(f as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthModel] Error parsing document ${doc.id}: $e');
      return HealthLog(
        id: doc.id,
        moodScore: MoodScale.unknown,
        checkInAt: DateTime.now(),
        sessionFeedbacks: [],
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'mood_score': moodScore,
      'check_in_at': Timestamp.fromDate(checkInAt),
      'note': note,
      'session_feedbacks': sessionFeedbacks.map((f) => f.toMap()).toList(),
    };
  }

  /// Retorna true si hay 3+ días consecutivos con mood_score == MoodScale.bad (-1).
  /// Se asume que la lista está ordenada por fecha descendente (más recientes primero).
  static bool hasDeterioration(List<HealthLog> lastLogs) {
    if (lastLogs.length < 3) return false;

    int consecutiveBadMoods = 0;
    DateTime? lastDate;

    for (final log in lastLogs) {
      if (log.moodScore != MoodScale.bad) {
        consecutiveBadMoods = 0;
        lastDate = log.checkInAt;
        continue;
      }

      if (lastDate == null) {
        consecutiveBadMoods = 1;
      } else {
        // Más robusto: Comparar sólo año/mes/día
        final date1 = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final date2 = DateTime(log.checkInAt.year, log.checkInAt.month, log.checkInAt.day);
        
        if (date1.difference(date2).inDays == 1) {
          consecutiveBadMoods++;
        } else {
          consecutiveBadMoods = 1;
        }
      }

      if (consecutiveBadMoods >= 3) return true;
      lastDate = log.checkInAt;
    }

    return false;
  }
}
