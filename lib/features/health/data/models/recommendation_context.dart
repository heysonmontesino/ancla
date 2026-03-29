class RecommendationSessionFeedbackSignal {
  const RecommendationSessionFeedbackSignal({
    required this.sessionId,
    required this.score,
  });

  final String sessionId;
  final int score;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'sessionId': sessionId, 'score': score};
  }
}

class RecommendationSessionCandidate {
  const RecommendationSessionCandidate({
    required this.id,
    required this.title,
    required this.category,
    required this.durationSeconds,
    required this.isPremium,
  });

  final String id;
  final String title;
  final String category;
  final int durationSeconds;
  final bool isPremium;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'category': category,
      'durationSeconds': durationSeconds,
      'isPremium': isPremium,
    };
  }
}

class RecommendationHardRules {
  const RecommendationHardRules({
    required this.preferredDuration,
    required this.supportLevelFloor,
    required this.candidateCategories,
    required this.blockedSessionIds,
    required this.forceProfessionalSupportNudge,
    required this.hasHighRecentLoad,
    required this.hasElevatedAcuteUsage,
  });

  // ENUM en backend: [short, medium, long]
  final String preferredDuration;
  // ENUM en backend: [standard, elevated]
  final String supportLevelFloor;
  final List<String> candidateCategories;
  final List<String> blockedSessionIds;
  final bool forceProfessionalSupportNudge;
  final bool hasHighRecentLoad;
  final bool hasElevatedAcuteUsage;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'preferredDuration': preferredDuration,
      'supportLevelFloor': supportLevelFloor,
      'candidateCategories': candidateCategories,
      'blockedSessionIds': blockedSessionIds,
      'forceProfessionalSupportNudge': forceProfessionalSupportNudge,
      'hasHighRecentLoad': hasHighRecentLoad,
      'hasElevatedAcuteUsage': hasElevatedAcuteUsage,
    };
  }
}

class RecommendationContext {
  const RecommendationContext({
    required this.todayMood,
    required this.weeklyMoods,
    required this.hasDeterioration,
    required this.sosActivationsLast7d,
    required this.sosActivationsLast24h,
    required this.recentSessionFeedback,
    required this.availableSessions,
    required this.hardRules,
  });

  final int? todayMood;
  final List<int?> weeklyMoods;
  final bool hasDeterioration;
  final int sosActivationsLast7d;
  final int sosActivationsLast24h;
  final List<RecommendationSessionFeedbackSignal> recentSessionFeedback;
  final List<RecommendationSessionCandidate> availableSessions;
  final RecommendationHardRules hardRules;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'todayMood': todayMood,
      'weeklyMoods': weeklyMoods,
      'hasDeterioration': hasDeterioration,
      'sosActivationsLast7d': sosActivationsLast7d,
      'sosActivationsLast24h': sosActivationsLast24h,
      'recentSessionFeedback': recentSessionFeedback
          .map((feedback) => feedback.toJson())
          .toList(),
      'availableSessions': availableSessions
          .map((session) => session.toJson())
          .toList(),
      'hardRules': hardRules.toJson(),
    };
  }
}
