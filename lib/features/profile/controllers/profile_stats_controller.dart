import '../../health/data/health_repository.dart';
import '../../health/data/models/health_log.dart';
import '../../home/data/sos_usage_repository.dart';

class ProfileStats {
  const ProfileStats({
    required this.checkInStreak,
    required this.sessionFeedbackCount,
    required this.sosActivations,
    this.isError = false,
  });

  /// Días consecutivos con al menos un check-in registrado (máx. 7 en v1).
  final int checkInStreak;

  /// Total de feedbacks de sesión dados en los últimos 7 días.
  final int sessionFeedbackCount;

  /// Eventos SOS registrados en los últimos 7 días.
  final int sosActivations;

  final bool isError;

  static const ProfileStats empty = ProfileStats(
    checkInStreak: 0,
    sessionFeedbackCount: 0,
    sosActivations: 0,
    isError: false,
  );

  static const ProfileStats error = ProfileStats(
    checkInStreak: 0,
    sessionFeedbackCount: 0,
    sosActivations: 0,
    isError: true,
  );
}

class ProfileStatsController {
  ProfileStatsController._();

  /// Carga las estadísticas del perfil combinando HealthRepository y
  /// SosUsageRepository. Devuelve [ProfileStats.error] ante cualquier error.
  static Future<ProfileStats> load() async {
    try {
      final results = await Future.wait([
        HealthRepository.fetchWeeklyLogs(),
        SosUsageRepository.fetchRecentSummary(),
      ]);

      final logs = results[0] as List<HealthLog>;
      final sosSummary = results[1] as SosUsageSummary;

      final int streak = _calculateStreak(logs);
      final int feedbackCount = logs.fold(
        0,
        (sum, log) => sum + log.sessionFeedbacks.length,
      );

      return ProfileStats(
        checkInStreak: streak,
        sessionFeedbackCount: feedbackCount,
        sosActivations: sosSummary.activationsLast7d,
      );
    } catch (e) {
      return ProfileStats.error;
    }
  }

  /// Cuenta días consecutivos con check-in comenzando desde hoy hacia atrás.
  /// Los logs llegan ordenados por fecha descendente (más reciente primero).
  static int _calculateStreak(List<HealthLog> logs) {
    if (logs.isEmpty) return 0;

    // Normaliza al día (sin hora) para comparar solo fechas.
    DateTime toDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

    final today = toDay(DateTime.now());
    int streak = 0;
    DateTime expected = today;

    for (final log in logs) {
      final logDay = toDay(log.checkInAt);
      if (logDay == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else if (logDay.isBefore(expected)) {
        // Hay un hueco: la racha se rompe.
        break;
      }
      // logDay > expected puede ocurrir si el orden no es exacto; lo ignoramos.
    }

    return streak;
  }
}
