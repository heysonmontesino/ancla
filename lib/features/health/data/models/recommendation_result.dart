import '../../../sessions/models/audio_session.dart';

class RecommendationResult {
  const RecommendationResult({
    required this.summary,
    required this.recommendedCategories,
    required this.recommendedSessionIds,
    required this.recommendedDuration,
    required this.supportLevel,
    required this.showProfessionalSupportNudge,
    required this.uiMessage,
    this.resolvedSessions = const [],
  });

  final String summary;
  final List<String> recommendedCategories;
  final List<String> recommendedSessionIds;
  // ENUM en backend: [short, medium, long]
  final String recommendedDuration;
  // ENUM en backend: [standard, elevated]
  final String supportLevel;
  final bool showProfessionalSupportNudge;
  final String uiMessage;

  /// Sesiones resueltas localmente tras la recomendación de la IA.
  final List<AudioSession> resolvedSessions;

  factory RecommendationResult.fromJson(Map<String, dynamic> json) {
    return RecommendationResult(
      summary: (json['summary'] as String? ?? '').trim(),
      recommendedCategories: (json['recommendedCategories'] as List? ?? [])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      recommendedSessionIds: (json['recommendedSessionIds'] as List? ?? [])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      recommendedDuration: (json['recommendedDuration'] as String? ?? '')
          .trim(),
      supportLevel: (json['supportLevel'] as String? ?? '').trim(),
      showProfessionalSupportNudge:
          json['showProfessionalSupportNudge'] as bool? ?? false,
      uiMessage: (json['uiMessage'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'summary': summary,
      'recommendedCategories': recommendedCategories,
      'recommendedSessionIds': recommendedSessionIds,
      'recommendedDuration': recommendedDuration,
      'supportLevel': supportLevel,
      'showProfessionalSupportNudge': showProfessionalSupportNudge,
      'uiMessage': uiMessage,
    };
  }

  /// Crea una copia con los datos resueltos por el servicio.
  RecommendationResult withResolvedData({
    required List<AudioSession> sessions,
  }) {
    return RecommendationResult(
      summary: summary,
      recommendedCategories: recommendedCategories,
      recommendedSessionIds: recommendedSessionIds,
      recommendedDuration: recommendedDuration,
      supportLevel: supportLevel,
      showProfessionalSupportNudge: showProfessionalSupportNudge,
      uiMessage: uiMessage,
      resolvedSessions: sessions,
    );
  }
}
