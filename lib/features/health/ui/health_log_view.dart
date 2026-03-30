import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../games/ui/games_screen.dart';
import '../../sessions/ui/library_screen.dart';
import '../../sessions/ui/session_player_screen.dart';
import '../data/health_repository.dart';
import '../data/recommendation_service.dart';
import '../data/models/health_log.dart';
import '../data/models/recommendation_result.dart';
import '../../../core/theme.dart';
import '../../../widgets/crisis_footer.dart';

class HealthLogView extends StatefulWidget {
  const HealthLogView({super.key});

  @override
  State<HealthLogView> createState() => _HealthLogViewState();
}

class _HealthLogViewState extends State<HealthLogView> {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  Stream<List<HealthLog>>? _logsStream;
  Future<RecommendationResult>? _recommendationFuture;
  StreamSubscription<User?>? _authSubscription;
  String _activeUid = '';
  int? _selectedMood;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _refreshLogsStream(uid: HealthRepository.currentUid, force: true);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) {
        return;
      }
      _refreshLogsStream(uid: user?.uid ?? '');
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  final Color _background = const Color(0xFF0B0E17);
  final Color _cardColor = const Color(0xFF161B26);
  final Color _primary = AppColors.primary;
  final Color _accent = AppColors.accent;

  String _getMoodLabel(int mood) {
    switch (mood) {
      case -1:
        return 'mal';
      case 0:
        return 'regular';
      case 1:
        return 'bien';
      default:
        return 'desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    // AUTO-RECOVERY: Si el UID cambió (por ejemplo, tras login anónimo tardío),
    // recreamos el stream para que la gráfica no se muestre vacía por error de timing.
    final currentUid = HealthRepository.currentUid;
    if (_lastKnownUid != currentUid && currentUid.isNotEmpty) {
      _lastKnownUid = currentUid;
      _logsStream = HealthRepository.watchWeeklyLogs();
    }

    return Scaffold(
      backgroundColor: _background,
      body: StreamBuilder<List<HealthLog>>(
        stream: _logsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            if (kDebugMode) debugPrint('[HealthLogView] Stream error: ${snapshot.error}');
          }
          final logs = snapshot.data ?? [];
          
          String getFormattedId(DateTime d) =>
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

          final todayId = getFormattedId(DateTime.now());
          final todayLog = logs.firstWhere(
            (l) => l.id == todayId,
            orElse: () => HealthLog(
              id: todayId,
              moodScore: MoodScale.unknown,
              checkInAt: DateTime.now(),
              sessionFeedbacks: [],
            ),
          );

          final bool alreadyCheckedIn = todayLog.moodScore != MoodScale.unknown;
          if (alreadyCheckedIn && _selectedMood == null) {
            _selectedMood = todayLog.moodScore;
          }

          return SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
            children: [
              // 1. HEADER
              Text(
                'Bitácora de Coherencia',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¿Cómo te sientes hoy?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.8), 
                ),
              ),
              const SizedBox(height: 40),

              // 2. CHECK-IN DIARIO
              _buildCheckInCard(alreadyCheckedIn, logs),
              const SizedBox(height: 32),

              if (snapshot.connectionState == ConnectionState.waiting && logs.isEmpty)
                const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _buildChartSection(logs),
              const SizedBox(height: 32),

              // 4. RECOMENDACIÓN IA
              _buildAiRecommendation(logs),
              const SizedBox(height: 48),
              const CrisisFooter(),
            ],
          ),
        );
      },
      ),
    );
  }

  Widget _buildCheckInCard(bool alreadyCheckedIn, List<HealthLog> logs) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MoodItem(
                    mood: -1,
                    emoji: '😢',
                    label: 'Mal',
                    isSelected: _selectedMood == -1,
                    onTap: () => setState(() => _selectedMood = -1),
                  ),
                  _MoodItem(
                    mood: 0,
                    emoji: '😐',
                    label: 'Regular',
                    isSelected: _selectedMood == 0,
                    onTap: () => setState(() => _selectedMood = 0),
                  ),
                  _MoodItem(
                    mood: 1,
                    emoji: '😊',
                    label: 'Bien',
                    isSelected: _selectedMood == 1,
                    onTap: () => setState(() => _selectedMood = 1),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (alreadyCheckedIn) ...[
                const SizedBox(height: 8),
                Text(
                  'Puedes actualizar tu estado de hoy si cambió.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_selectedMood == null || _isSaving || HealthRepository.currentUid.isEmpty)
                      ? null
                      : _saveCheckIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(alreadyCheckedIn ? 'Actualizar estado' : 'Guardar estado'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveCheckIn() async {
    final uid = HealthRepository.currentUid;
    if (_selectedMood == null || uid.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await HealthRepository.saveDailyCheckIn(_selectedMood!);

      if (!mounted) return;
      
      setState(() {
        _logsStream = HealthRepository.watchWeeklyLogs();
        _recommendationFuture = null;
      });

      _analytics.logEvent(
        name: 'mood_saved_success',
        parameters: {
          'mood_score': _selectedMood!,
          'mood_label': _getMoodLabel(_selectedMood!),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro de bienestar guardado correctamente'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pudimos guardar tu registro: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  Widget _buildChartSection(List<HealthLog> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tendencia semanal',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          height: 200,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: CustomPaint(painter: _WeeklyChartPainter(logs: logs)),
        ),
      ],
    );
  }

  Widget _buildAiRecommendation(List<HealthLog> logs) {
    _recommendationFuture ??= RecommendationService.buildRecommendation(weeklyLogs: logs);
    
    return FutureBuilder<RecommendationResult>(
      future: _recommendationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildRecommendationShell(
            accentColor: _accent,
            backgroundColors: const [Color(0xFF16231B), Color(0xFF0B120E)],
            title: 'Recomendacion inteligente',
            summary:
                'Preparando una sugerencia breve con tu bitacora reciente y uso reciente de SOS.',
            footer:
                'Si la conexion con IA no responde, se mantiene una recomendacion local segura.',
            child: const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final RecommendationResult? result = snapshot.data;
        if (result == null) {
          return _buildRecommendationShell(
            accentColor: _accent,
            backgroundColors: const [Color(0xFF16231B), Color(0xFF0B120E)],
            title: 'Recomendacion inteligente',
            summary: _getMotivationalQuote(logs),
            footer:
                'Explora una practica breve y vuelve a revisar tu bitacora mañana.',
            child: _buildLibraryButton(),
          );
        }

        final bool elevated = result.supportLevel == 'elevated';
        final Color accentColor = elevated
            ? Colors.redAccent.shade100
            : _accent;
        final List<Color> backgroundColors = elevated
            ? const [Color(0xFF2D1618), Color(0xFF160B0C)]
            : const [Color(0xFF16231B), Color(0xFF0B120E)];

        return _buildRecommendationShell(
          accentColor: accentColor,
          backgroundColors: backgroundColors,
          title: elevated
              ? 'Recomendacion de cuidado reciente'
              : 'Recomendacion inteligente',
          summary: result.summary,
          footer: result.uiMessage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.recommendedCategories.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.recommendedCategories
                      .map(
                        (category) => _buildCategoryChip(category, accentColor),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
              ],
              if (result.resolvedSessions.isNotEmpty) ...[
                ...result.resolvedSessions.map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  SessionPlayerScreen(session: session),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                session.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              _formatDuration(session.durationSeconds),
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                _buildLibraryButton(),
              if (elevated) ...[const SizedBox(height: 8), _buildGamesButton()],
              if (result.showProfessionalSupportNudge) ...[
                const SizedBox(height: 10),
                Text(
                  'Si esta carga se repite varios dias, considera apoyarte en una persona de confianza o en atencion profesional.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendationShell({
    required Color accentColor,
    required List<Color> backgroundColors,
    required String title,
    required String summary,
    required String footer,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: backgroundColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: accentColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            summary,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.9), // Más contraste
              height: 1.5,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          child,
          const SizedBox(height: 10),
          Text(
            footer,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Text(
        _categoryLabel(category),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildLibraryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const LibraryScreen()),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Explorar sesiones'),
      ),
    );
  }

  Widget _buildGamesButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const GamesScreen()),
          );
        },
        icon: const Icon(Icons.self_improvement, size: 16),
        label: const Text('Prueba un ejercicio'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  String _getMotivationalQuote(List<HealthLog> logs) {
    final validLogs = logs.where((l) => l.moodScore != MoodScale.unknown).toList();
    if (validLogs.isEmpty) {
      return 'Registra tu primer estado para recibir recomendaciones.';
    }
    final avg =
        validLogs.map((l) => l.moodScore).reduce((a, b) => a + b) / validLogs.length;
    if (avg >= 0.5) {
      return '¡Qué gran semana! Mantén el ritmo con tu sesión favorita.';
    }
    if (avg >= 0) {
      return 'Día a día construyes tu equilibrio. Sigue respirando.';
    }
    return 'Cada respiración cuenta. Estamos aquí para acompañarte.';
  }

  String _formatDuration(int durationSeconds) {
    final int minutes = (durationSeconds / 60).ceil();
    return '$minutes min';
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'grounding':
        return 'Grounding';
      case 'breathing':
        return 'Respiracion';
      case 'calm':
        return 'Calma';
      case 'sleep':
        return 'Sueno';
      case 'gratitude':
        return 'Gratitud';
      case 'focus':
        return 'Foco';
      case 'maintenance':
        return 'Mantenimiento';
      default:
        return category;
    }
  }
}

class _MoodItem extends StatelessWidget {
  final int mood;
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _MoodItem({
    required this.mood,
    required this.emoji,
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.white10,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChartPainter extends CustomPainter {
  final List<HealthLog> logs;

  _WeeklyChartPainter({required this.logs});

  @override
  void paint(Canvas canvas, Size size) {
    // Definimos los días de la semana
    final daysLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final now = DateTime.now();

    // Usar una función local para consistencia de IDs de fecha (YYYY-MM-DD)
    String getFormattedId(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final List<int?> scores = [];
    // Mapear los últimos 7 días naturales terminando en hoy.
    // Iteramos de 6 días atrás hasta hoy (0).
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateId = getFormattedId(date);
      final log = logs.firstWhere(
        (l) => l.id == dateId,
        orElse: () => HealthLog(
          id: '',
          moodScore: MoodScale.unknown,
          checkInAt: date,
          sessionFeedbacks: [],
        ),
      );
      scores.add(log.moodScore == MoodScale.unknown ? null : log.moodScore);
    }

    final double w = size.width;
    final double h = size.height;
    
    // Dejar márgenes laterales para que los puntos no se corten
    final double marginX = 20;
    final double chartWidth = w - (2 * marginX);
    final double stepX = chartWidth / 6;
    
    final double centerY = h / 2;
    final double stepY = (h / 2) - 25;

    // Pintar ejes guías
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, centerY), Offset(w, centerY), guidePaint);
    canvas.drawLine(
      Offset(0, centerY - stepY),
      Offset(w, centerY - stepY),
      guidePaint,
    );
    canvas.drawLine(
      Offset(0, centerY + stepY),
      Offset(w, centerY + stepY),
      guidePaint,
    );

    final linePaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    bool firstPoint = true;

    for (int i = 0; i < scores.length; i++) {
      final score = scores[i];
      if (score == null) {
        firstPoint = true;
        continue;
      }

      final x = marginX + (i * stepX);
      final y = centerY - (score * stepY);

      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    // Pintar puntos y etiquetas
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < scores.length; i++) {
      final score = scores[i];
      final x = marginX + (i * stepX);

      // Etiquetas día
      final date = now.subtract(Duration(days: 6 - i));
      final label = daysLabels[date.weekday - 1];

      textPainter.text = TextSpan(
        text: label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - (textPainter.width / 2), h - 12));

      if (score != null) {
        final y = centerY - (score * stepY);
        final dotColor = score == 1
            ? Colors.greenAccent
            : (score == 0 ? Colors.grey : Colors.redAccent);

        canvas.drawCircle(Offset(x, y), 5, Paint()..color = dotColor);
        canvas.drawCircle(
          Offset(x, y),
          8,
          Paint()..color = dotColor.withValues(alpha: 0.2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
