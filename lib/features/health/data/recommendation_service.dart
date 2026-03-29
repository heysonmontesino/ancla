import '../../ai_chat/data/asistente_emocional_service.dart';
import '../../home/data/sos_usage_repository.dart';
import '../../sessions/data/firestore_audio_repository.dart';
import '../../sessions/models/audio_session.dart';
import 'health_repository.dart';
import 'models/health_log.dart';
import 'models/recommendation_context.dart';
import 'models/recommendation_result.dart';

class RecommendationService {
  RecommendationService._();

  static const List<String> _acutePriorityCategories = <String>[
    'grounding',
    'breathing',
    'calm',
  ];
  static const List<String> _stablePriorityCategories = <String>[
    'maintenance',
    'sleep',
    'gratitude',
    'focus',
  ];
  static const List<String> _fallbackPriorityCategories = <String>[
    'calm',
    'breathing',
    'maintenance',
    'sleep',
  ];
  static const Set<String> _unsafeClinicalTerms = <String>{
    'depresion',
    'depresión',
    'ansiedad severa',
    'trastorno',
    'diagnostico',
    'diagnóstico',
    'riesgo clinico',
    'riesgo clínico',
  };

  static Future<RecommendationResult> buildRecommendation({
    List<HealthLog>? weeklyLogs,
  }) async {
    final List<HealthLog> logs = _sortLogs(
      weeklyLogs ?? await HealthRepository.fetchWeeklyLogs(),
    );

    final List<AudioSession> sessions =
        await FirestoreAudioRepository.fetchSessions();
    final SosUsageSummary sosSummary =
        await SosUsageRepository.fetchRecentSummary();
    final RecommendationContext context = _buildContext(
      logs: logs,
      sosSummary: sosSummary,
      sessions: sessions,
    );

    final RecommendationResult localResult = _buildLocalRecommendation(context);
    final List<AudioSession> localSessions = _resolveSessions(
      ids: localResult.recommendedSessionIds,
      sessions: sessions,
    );

    final AsistenteEmocionalService aiService = AsistenteEmocionalService();
    try {
      final RecommendationResult aiResult = await aiService.fetchRecommendation(
        context,
      );
      final RecommendationResult merged = _mergeWithHardRules(
        aiResult: aiResult,
        localResult: localResult,
        context: context,
      );

      return merged.withResolvedData(
        sessions: _resolveSessions(
          ids: merged.recommendedSessionIds,
          sessions: sessions,
        ),
      );
    } catch (_) {
      return localResult.withResolvedData(
        sessions: localSessions,
      );
    } finally {
      aiService.dispose();
    }
  }

  static RecommendationContext _buildContext({
    required List<HealthLog> logs,
    required SosUsageSummary sosSummary,
    required List<AudioSession> sessions,
  }) {
    final Map<String, HealthLog> logsById = <String, HealthLog>{
      for (final HealthLog log in logs) log.id: log,
    };
    final DateTime today = DateTime.now();
    final List<int?> weeklyMoods = List<int?>.generate(7, (int index) {
      final DateTime date = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: index));
      final String id =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final HealthLog? log = logsById[id];
      if (log == null || log.moodScore == MoodScale.unknown) {
        return null;
      }
      return log.moodScore;
    });

    final List<RecommendationSessionFeedbackSignal> feedback =
        _extractRecentFeedback(logs);
    final List<String> blockedSessionIds = feedback
        .where((signal) => signal.score < 0)
        .map((signal) => signal.sessionId)
        .toSet()
        .toList();

    final bool hasDeterioration = HealthLog.hasDeterioration(logs);
    final bool hasElevatedAcuteUsage =
        sosSummary.activationsLast24h > 0 || sosSummary.activationsLast7d >= 3;
    final bool hasHighRecentLoad =
        hasDeterioration || sosSummary.activationsLast7d >= 3;
    final String preferredDuration = _preferredDuration(
      todayMood: weeklyMoods.first,
      acute: hasElevatedAcuteUsage,
    );
    final List<String> candidateCategories = _candidateCategories(
      todayMood: weeklyMoods.first,
      acute: hasElevatedAcuteUsage,
      deterioration: hasDeterioration,
      sessions: sessions,
    );

    return RecommendationContext(
      todayMood: weeklyMoods.first,
      weeklyMoods: weeklyMoods,
      hasDeterioration: hasDeterioration,
      sosActivationsLast7d: sosSummary.activationsLast7d,
      sosActivationsLast24h: sosSummary.activationsLast24h,
      recentSessionFeedback: feedback,
      availableSessions: sessions
          .map(
            (AudioSession session) => RecommendationSessionCandidate(
              id: session.id,
              title: session.title,
              category: _recommendationCategoryForSession(session),
              durationSeconds: session.durationSeconds,
              isPremium: session.isPremium,
            ),
          )
          .toList(),
      hardRules: RecommendationHardRules(
        preferredDuration: preferredDuration,
        supportLevelFloor: hasHighRecentLoad ? 'elevated' : 'standard',
        candidateCategories: candidateCategories,
        blockedSessionIds: blockedSessionIds,
        forceProfessionalSupportNudge: hasHighRecentLoad,
        hasHighRecentLoad: hasHighRecentLoad,
        hasElevatedAcuteUsage: hasElevatedAcuteUsage,
      ),
    );
  }

  static RecommendationResult _buildLocalRecommendation(
    RecommendationContext context,
  ) {
    final List<String> blocked = context.hardRules.blockedSessionIds;
    final List<RecommendationSessionCandidate> candidates =
        context.availableSessions
            .where((session) => !blocked.contains(session.id))
            .toList()
          ..sort(
            (
              RecommendationSessionCandidate a,
              RecommendationSessionCandidate b,
            ) => _scoreCandidate(
              context,
              b,
            ).compareTo(_scoreCandidate(context, a)),
          );

    final List<String> recommendedSessionIds = candidates
        .take(2)
        .map((session) => session.id)
        .toList();
    final List<String> recommendedCategories =
        <String>[
          ...candidates.take(2).map((session) => session.category),
          ...context.hardRules.candidateCategories,
        ].fold<List<String>>(<String>[], (list, value) {
          if (!list.contains(value)) {
            list.add(value);
          }
          return list;
        });

    final bool elevated = context.hardRules.supportLevelFloor == 'elevated';
    final bool acuteNow =
        context.todayMood == MoodScale.bad || context.sosActivationsLast24h > 0;

    return RecommendationResult(
      summary: _localSummary(context),
      recommendedCategories: recommendedCategories.take(3).toList(),
      recommendedSessionIds: recommendedSessionIds,
      recommendedDuration: context.hardRules.preferredDuration,
      supportLevel: elevated ? 'elevated' : 'standard',
      showProfessionalSupportNudge:
          context.hardRules.forceProfessionalSupportNudge,
      uiMessage: acuteNow
          ? 'Hoy puede ayudar empezar con una practica breve de regulacion. Si esto se repite con frecuencia, considera buscar apoyo profesional o una persona de confianza.'
          : elevated
          ? 'Puede servir volver a una practica breve y repetible. Si la carga se mantiene varios dias, considera apoyarte en una persona de confianza o en atencion profesional.'
          : 'Tu registro reciente permite sostener una practica de cuidado y mantenimiento, sin exigir demasiado.',
    );
  }

  static RecommendationResult _mergeWithHardRules({
    required RecommendationResult aiResult,
    required RecommendationResult localResult,
    required RecommendationContext context,
  }) {
    final Set<String> allowedCategories = context.availableSessions
        .map((session) => session.category)
        .toSet();
    final Set<String> blockedIds = context.hardRules.blockedSessionIds.toSet();
    final Set<String> allowedIds = context.availableSessions
        .map((session) => session.id)
        .where((id) => !blockedIds.contains(id))
        .toSet();

    final List<String> recommendedCategories = aiResult.recommendedCategories
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty && allowedCategories.contains(value))
        .toList();
    final List<String> recommendedSessionIds = aiResult.recommendedSessionIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && allowedIds.contains(value))
        .toList();

    final String sanitizedSummary = _sanitizeText(
      aiResult.summary,
      fallback: localResult.summary,
    );
    final String sanitizedMessage = _sanitizeText(
      aiResult.uiMessage,
      fallback: localResult.uiMessage,
    );
    final String recommendedDuration = _mergeDuration(
      aiResult.recommendedDuration,
      fallback: localResult.recommendedDuration,
      forceShort: context.hardRules.preferredDuration == 'short',
    );

    return RecommendationResult(
      summary: sanitizedSummary,
      recommendedCategories: recommendedCategories.isEmpty
          ? localResult.recommendedCategories
          : recommendedCategories,
      recommendedSessionIds: recommendedSessionIds.isEmpty
          ? localResult.recommendedSessionIds
          : recommendedSessionIds,
      recommendedDuration: recommendedDuration,
      supportLevel:
          context.hardRules.supportLevelFloor == 'elevated' ||
              aiResult.supportLevel.trim().toLowerCase() == 'elevated'
          ? 'elevated'
          : 'standard',
      showProfessionalSupportNudge:
          context.hardRules.forceProfessionalSupportNudge ||
          aiResult.showProfessionalSupportNudge,
      uiMessage: sanitizedMessage,
    );
  }

  static List<HealthLog> _sortLogs(List<HealthLog> logs) {
    final List<HealthLog> copy = List<HealthLog>.from(logs);
    copy.sort((a, b) => b.id.compareTo(a.id));
    return copy;
  }

  static List<RecommendationSessionFeedbackSignal> _extractRecentFeedback(
    List<HealthLog> logs,
  ) {
    final List<SessionFeedback> feedback =
        logs.expand((log) => log.sessionFeedbacks).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return feedback.take(6).map((SessionFeedback value) {
      return RecommendationSessionFeedbackSignal(
        sessionId: value.sessionId,
        score: value.score,
      );
    }).toList();
  }

  static String _preferredDuration({
    required int? todayMood,
    required bool acute,
  }) {
    if (acute || todayMood == MoodScale.bad) {
      return 'short';
    }
    if (todayMood == MoodScale.good) {
      return 'long';
    }
    return 'medium';
  }

  static List<String> _candidateCategories({
    required int? todayMood,
    required bool acute,
    required bool deterioration,
    required List<AudioSession> sessions,
  }) {
    final List<String> priorities = acute || todayMood == MoodScale.bad
        ? _acutePriorityCategories
        : todayMood == MoodScale.good && !deterioration
        ? _stablePriorityCategories
        : _fallbackPriorityCategories;
    final Set<String> available = sessions
        .map(_recommendationCategoryForSession)
        .toSet();

    return priorities.where(available.contains).toList();
  }

  static String _recommendationCategoryForSession(AudioSession session) {
    final String title = session.title.toLowerCase();

    if (title.contains('5-4-3-2-1') ||
        title.contains('grounding') ||
        title.contains('ancla') ||
        title.contains('sentidos')) {
      return 'grounding';
    }
    if (title.contains('respir') || title.contains('breath')) {
      return 'breathing';
    }
    if (title.contains('gratitud')) {
      return 'gratitude';
    }

    switch (session.category) {
      case SessionCategory.anxiety:
        return 'grounding';
      case SessionCategory.stress:
        return 'calm';
      case SessionCategory.sleep:
        return 'sleep';
      case SessionCategory.focus:
        return 'focus';
      case SessionCategory.mood:
        return 'maintenance';
    }
  }

  static int _scoreCandidate(
    RecommendationContext context,
    RecommendationSessionCandidate session,
  ) {
    int score = 0;

    final int categoryIndex = context.hardRules.candidateCategories.indexOf(
      session.category,
    );
    if (categoryIndex >= 0) {
      score += 80 - (categoryIndex * 10);
    }

    if (context.hardRules.preferredDuration == 'short') {
      score += session.durationSeconds <= 300 ? 35 : 0;
    } else if (context.hardRules.preferredDuration == 'long') {
      score += session.durationSeconds >= 480 ? 25 : 0;
    } else {
      score += session.durationSeconds <= 420 ? 12 : 0;
    }

    final RecommendationSessionFeedbackSignal? feedback = context
        .recentSessionFeedback
        .cast<RecommendationSessionFeedbackSignal?>()
        .firstWhere(
          (value) => value?.sessionId == session.id,
          orElse: () => null,
        );
    if (feedback != null) {
      score += feedback.score > 0 ? 20 : -120;
    }

    if (!session.isPremium) {
      score += 8;
    }

    return score;
  }

  static String _localSummary(RecommendationContext context) {
    if (context.hardRules.hasHighRecentLoad &&
        context.sosActivationsLast7d >= 3) {
      return 'En los ultimos dias aparece una carga reciente alta y mayor necesidad de regulacion breve.';
    }
    if (context.todayMood == MoodScale.bad ||
        context.sosActivationsLast24h > 0) {
      return 'Hoy parece mas util empezar con regulacion breve y concreta.';
    }
    if ((context.todayMood ?? MoodScale.neutral) >= MoodScale.neutral &&
        !context.hasDeterioration) {
      return 'La semana reciente sugiere una base mas estable para sostener practicas de mantenimiento.';
    }
    return 'Tu registro reciente sugiere combinar calma breve con una practica de cuidado sostenido.';
  }

  static String _sanitizeText(String value, {required String fallback}) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return fallback;
    }

    final String lower = normalized.toLowerCase();
    for (final String term in _unsafeClinicalTerms) {
      if (lower.contains(term)) {
        return fallback;
      }
    }

    return normalized;
  }

  static String _mergeDuration(
    String aiValue, {
    required String fallback,
    required bool forceShort,
  }) {
    final String normalized = aiValue.trim().toLowerCase();
    if (forceShort) {
      return 'short';
    }
    if (normalized == 'short' ||
        normalized == 'medium' ||
        normalized == 'long') {
      return normalized;
    }
    return fallback;
  }

  static List<AudioSession> _resolveSessions({
    required List<String> ids,
    required List<AudioSession> sessions,
  }) {
    final Map<String, AudioSession> byId = <String, AudioSession>{
      for (final AudioSession session in sessions) session.id: session,
    };

    return ids.map((id) => byId[id]).whereType<AudioSession>().toList();
  }
}
