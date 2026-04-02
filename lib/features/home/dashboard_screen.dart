import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../sessions/controllers/session_playback_controller.dart';
import '../sessions/data/firestore_audio_repository.dart';
import '../sessions/models/audio_session.dart';
import '../sessions/ui/library_screen.dart';
import '../sessions/ui/session_player_screen.dart';
import '../../core/ui/widgets/organic_background.dart';
import '../health/data/health_repository.dart';
import '../health/ui/health_log_view.dart';
import '../games/ui/games_screen.dart';
import '../home/ui/ai_assistant_entry_sheet.dart';
import '../pet/ui/pet_widget.dart';
import '../pet/models/pet_profile.dart';
import '../pet/providers/pet_providers.dart';
import '../profile/ui/profile_screen.dart';
import '../profile/data/user_profile_repository.dart';
import '../ai_chat/presentation/asistente_emocional_screen.dart';
import 'emergency_screen.dart';

const Color _dashboardBackground = AppColors.ivory;
const Color _dashboardForeground = AppColors.textDark;
const Color _dashboardPrimary = AppColors.primary;
const Color _dashboardSecondary = AppColors.sageLight;
const Color _dashboardCard = Colors.white;
const Color _dashboardMuted = AppColors.textMuted;
const Color _sosBackground = Color(0xFF0D1F1A);
const Color _sosForeground = Color(0xFFEDF2F7);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _sosController;
  late Animation<double> _sosPulse;
  late final Stream<List<AudioSession>> _featuredSessionsStream;

  static const double _hPadding = 24.0;
  static const double _vSection = 32.0;
  static const double _vComponent = 16.0;

  @override
  void initState() {
    super.initState();
    _sosController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _sosController.duration = const Duration(seconds: 3);
    _featuredSessionsStream = FirestoreAudioRepository.watchFeaturedSessions(
      limit: 3,
    );
    _sosPulse = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _sosController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _sosController.dispose();
    super.dispose();
  }

  void _navigateToEmergency() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            FadeTransition(opacity: animation, child: const EmergencyScreen()),
      ),
    );
  }

  Future<void> _navigateToChat() async {
    final AiAssistantEntryResult? result =
        await showModalBottomSheet<AiAssistantEntryResult>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: AppColors.ivory,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          builder: (_) => const AiAssistantEntrySheet(),
        );

    if (!mounted || result == null) {
      return;
    }

    switch (result.action) {
      case AiAssistantEntryAction.openAssistant:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => AsistenteEmocionalScreen(
                  initialStatus: result.status,
                ),
          ),
        );
        break;
      case AiAssistantEntryAction.openJournal:
        setState(() => _selectedIndex = 1);
        break;
      case AiAssistantEntryAction.openLibrary:
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const LibraryScreen()));
        break;
      case AiAssistantEntryAction.openEmergency:
        _navigateToEmergency();
        break;
    }
  }

  void _handleNavTap(int index) {
    if (index == 0) {
      setState(() => _selectedIndex = 0);
      return;
    }

    if (index == 1) {
      setState(() => _selectedIndex = 1);
      return;
    }

    if (index == 2) {
      _navigateToEmergency();
      return;
    }

    if (index == 3) {
      setState(() => _selectedIndex = 3);
      return;
    }
  }

  void _openAudioSession(AudioSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionPlayerScreen(session: session),
      ),
    );
  }

  Future<void> _makeEmergencyCall() async {
    final Uri url = Uri.parse('tel:106');
    try {
      final bool canCall = await canLaunchUrl(url);
      if (canCall) {
        await launchUrl(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se pudo iniciar la llamada. Marca 106 manualmente.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              backgroundColor: const Color(0xFF7B1A1A),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al llamar: verifica permisos o marca 106 manualmente.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
            backgroundColor: const Color(0xFF7B1A1A),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _closeActiveSession() async {
    await SessionPlaybackController.instance.closeSession();
  }

  String _greetingForHour(int hour) {
    if (hour < 12) {
      return 'Buenos dias,';
    }
    if (hour < 18) {
      return 'Buenas tardes,';
    }
    return 'Buenas noches,';
  }

  String _categoryLabel(SessionCategory category) => category.displayName;

  String _formatMinutes(int durationSeconds) {
    final int minutes = (durationSeconds / 60).ceil();
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final SessionPlaybackController playback =
        SessionPlaybackController.instance;
    final DateTime now = DateTime.now();
    final String greeting = _greetingForHour(now.hour);

    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final bool hasPlaybackSession = playback.hasCurrentSession;
        final AudioSession? currentSession = playback.currentSession;

        return Theme(
          data: AppTheme.lightTheme,
          child: Scaffold(
            backgroundColor: _dashboardBackground,
            extendBody: true,
            body: Stack(
              children: [
                Positioned.fill(
                  child: const OrganicBackgroundGradient(
                    child: SizedBox.expand(),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _selectedIndex == 1
                        ? const HealthLogView(key: ValueKey('health_view'))
                        : _selectedIndex == 3
                        ? const ProfileScreen(key: ValueKey('profile_view'))
                        : CustomScrollView(
                            key: const ValueKey('home_view'),
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              const SliverSafeArea(
                                top: true,
                                bottom: false,
                                sliver: SliverToBoxAdapter(
                                  child: SizedBox(height: _vComponent),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _hPadding,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: StreamBuilder<String?>(
                                    stream:
                                        UserProfileRepository.watchPreferredName(),
                                    builder: (context, snapshot) {
                                      final userName =
                                          UserProfileRepository.resolveVisibleName(
                                            preferredName: snapshot.data,
                                          );
                                      return _DashboardHeader(
                                        greeting: greeting,
                                        userName: userName,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: _vComponent),
                              ),
                              const SliverToBoxAdapter(
                                child: _DashboardDailyStatus(),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: _vSection),
                              ),
                              const SliverToBoxAdapter(
                                child: Center(child: PetWidget()),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: _vSection),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _hPadding,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Semantics(
                                    label: 'Botón de emergencia SOS',
                                    button: true,
                                    child: GestureDetector(
                                      onTap: _navigateToEmergency,
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: _sosBackground,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          border: Border.all(
                                            color: const Color(
                                              0xFF4CAF7D,
                                            ).withValues(alpha: 0.3),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned(
                                              right: -20,
                                              bottom: -20,
                                              child: AnimatedBuilder(
                                                animation: _sosPulse,
                                                builder: (context, _) => Transform.scale(
                                                  scale:
                                                      1.0 +
                                                      (_sosPulse.value * 0.1),
                                                  child: Container(
                                                    width:
                                                        120 *
                                                        (1.0 +
                                                            (_sosPulse.value *
                                                                0.2)),
                                                    height:
                                                        120 *
                                                        (1.0 +
                                                            (_sosPulse.value *
                                                                0.2)),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      gradient: RadialGradient(
                                                        colors: [
                                                          const Color(
                                                            0xFF4CAF7D,
                                                          ).withValues(
                                                            alpha:
                                                                0.1 *
                                                                (1.0 -
                                                                    _sosPulse
                                                                        .value),
                                                          ),
                                                          const Color(
                                                            0xFF4CAF7D,
                                                          ).withValues(
                                                            alpha: 0.0,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF4CAF7D,
                                                    ).withValues(alpha: 0.15),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.emergency_rounded,
                                                    color: Color(0xFF4CAF7D),
                                                    size: 22,
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        '¿Necesitas ayuda ahora?',
                                                        style:
                                                            GoogleFonts.plusJakartaSans(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  _sosForeground,
                                                              letterSpacing:
                                                                  -0.3,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Línea 106 · atención inmediata',
                                                        style:
                                                            GoogleFonts.plusJakartaSans(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color:
                                                                  _sosForeground
                                                                      .withValues(
                                                                        alpha:
                                                                            0.5,
                                                                      ),
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: _makeEmergencyCall,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    child: Ink(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            const Color(
                                                              0xFF4CAF7D,
                                                            ).withValues(
                                                              alpha: 0.15,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              const Color(
                                                                0xFF4CAF7D,
                                                              ).withValues(
                                                                alpha: 0.4,
                                                              ),
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        'Llamar 106',
                                                        style:
                                                            GoogleFonts.plusJakartaSans(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  const Color(
                                                                    0xFF4CAF7D,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SliverToBoxAdapter(
                                child: SizedBox(height: _vSection),
                              ),

                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _hPadding,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: _QuickActionsGrid(
                                    onLogMood: () =>
                                        setState(() => _selectedIndex = 1),
                                    onOpenChat: _navigateToChat,
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: _vSection),
                              ),
                              if (hasPlaybackSession && currentSession != null)
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _hPadding,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: _vSection,
                                      ),
                                      child: _ActiveSessionCard(
                                        title: currentSession.title,
                                        subtitle:
                                            '${_categoryLabel(currentSession.category).toUpperCase()} · ${_formatMinutes(currentSession.durationSeconds)}',
                                        isPlaying: playback.isPlaybackActive,
                                        coverImageUrl:
                                            currentSession.coverImageUrl,
                                        fallbackCoverAssetPath: currentSession
                                            .category
                                            .coverImagePath,
                                        onContinue: () =>
                                            _openAudioSession(currentSession),
                                        onClose: _closeActiveSession,
                                      ),
                                    ),
                                  ),
                                ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _hPadding,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Sesiones recomendadas',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                    color: _dashboardForeground,
                                                    letterSpacing: -0.5,
                                                  ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      const LibraryScreen(),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              'VER TODO',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: _dashboardPrimary,
                                                    letterSpacing: 1.0,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Contenido seleccionado para tu bienestar.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: _dashboardMuted,
                                        ),
                                      ),
                                      const SizedBox(height: _vComponent),
                                      StreamBuilder<List<AudioSession>>(
                                        stream: _featuredSessionsStream,
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 24,
                                              ),
                                              child: Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            _dashboardPrimary,
                                                      ),
                                                ),
                                              ),
                                            );
                                          }

                                          if (snapshot.hasError) {
                                            return Text(
                                              'La biblioteca no está disponible en este momento.',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: _dashboardMuted,
                                                    height: 1.45,
                                                  ),
                                            );
                                          }

                                          final sessions =
                                              snapshot.data ??
                                              const <AudioSession>[];
                                          if (sessions.isEmpty) {
                                            return Text(
                                              'Aun no hay sesiones publicadas en la biblioteca.',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: _dashboardMuted,
                                                    height: 1.45,
                                                  ),
                                            );
                                          }

                                          final heroSession = sessions.first;
                                          final secondarySessions = sessions
                                              .skip(1)
                                              .toList();

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _HeroRecommendationCard(
                                                session: heroSession,
                                                onTap: () => _openAudioSession(
                                                  heroSession,
                                                ),
                                                categoryLabel: _categoryLabel(
                                                  heroSession.category,
                                                ),
                                                durationLabel: _formatMinutes(
                                                  heroSession.durationSeconds,
                                                ),
                                              ),
                                              if (secondarySessions
                                                  .isNotEmpty) ...[
                                                const SizedBox(
                                                  height: _vSection,
                                                ),
                                                SizedBox(
                                                  height:
                                                      170, // Height for secondary carousel
                                                  child: ListView.builder(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    padding: EdgeInsets.zero,
                                                    physics:
                                                        const BouncingScrollPhysics(),
                                                    itemCount: secondarySessions
                                                        .length,
                                                    itemBuilder: (context, index) {
                                                      final session =
                                                          secondarySessions[index];
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 12,
                                                            ),
                                                        child: _SecondaryRecommendationCard(
                                                          session: session,
                                                          onTap: () =>
                                                              _openAudioSession(
                                                                session,
                                                              ),
                                                          categoryLabel:
                                                              _categoryLabel(
                                                                session
                                                                    .category,
                                                              ),
                                                          durationLabel:
                                                              _formatMinutes(
                                                                session
                                                                    .durationSeconds,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: _vSection),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _hPadding,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const GamesScreen(),
                                        ),
                                      ),
                                      child: Ink(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: _dashboardCard,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: _dashboardPrimary
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: const Icon(
                                                Icons.self_improvement,
                                                color: _dashboardPrimary,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Ejercicios cognitivos',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          _dashboardForeground,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Entrena tu mente y enfoque',
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              _dashboardMuted,
                                                          height: 1.4,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: _dashboardMuted,
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: _vSection),
                              ),

                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height:
                                      120 +
                                      MediaQuery.of(context).padding.bottom,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _FloatingNavBar(
              selectedIndex: _selectedIndex,
              onItemTapped: _handleNavTap,
              backgroundColor: _selectedIndex == 1
                  ? const Color(0xFF0D1F17)
                  : _dashboardBackground,
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onLogMood;
  final VoidCallback onOpenChat;

  const _QuickActionsGrid({required this.onLogMood, required this.onOpenChat});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            '¿Cómo estás hoy?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _dashboardForeground,
              letterSpacing: -0.4,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                title: 'Bitácora',
                subtitle: 'Registrar estado',
                icon: Icons.edit_note_rounded,
                color: const Color(0xFFC8E6D9),
                onTap: onLogMood,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                title: 'Asistente',
                subtitle: 'Chat de apoyo',
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFFE6D9C8),
                onTap: onOpenChat,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String greeting;
  final String userName;

  const _DashboardHeader({required this.greeting, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _dashboardMuted,
                  letterSpacing: 0.1,
                ),
              ),
              Text(
                userName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _dashboardForeground,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: _dashboardPrimary.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: _dashboardPrimary.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: _dashboardPrimary,
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _DashboardDailyStatus extends StatelessWidget {
  const _DashboardDailyStatus();

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Comenzando viaje';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Justo ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ayer';
    return 'Hace ${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PetProfile?>(
      stream: petProfileProvider(),
      builder: (context, petSnapshot) {
        final profile = petSnapshot.data;
        if (profile == null) return const SizedBox.shrink();

        final String timeLabel = _formatTimeAgo(profile.lastInteractionAt);

        return StreamBuilder(
          stream: HealthRepository.watchWeeklyLogs(),
          builder: (context, logsSnapshot) {
            final int racha =
                logsSnapshot.hasData
                    ? HealthRepository.calculateCheckInStreak(
                      logsSnapshot.data!,
                    )
                    : profile.petRacha;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  if (racha > 0) ...[
                    _StatusChip(
                      icon: Icons.local_fire_department_rounded,
                      label: '$racha días 🔥',
                      color: const Color(0xFFFF9E58),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _StatusChip(
                    icon: Icons.auto_awesome_rounded,
                    label: timeLabel,
                    color: _dashboardPrimary,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.9),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _dashboardCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Color.lerp(color, Colors.black, 0.4),
                  size: 20,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _dashboardForeground,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _dashboardMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({
    required this.title,
    required this.subtitle,
    required this.isPlaying,
    required this.coverImageUrl,
    required this.fallbackCoverAssetPath,
    required this.onContinue,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final bool isPlaying;
  final String? coverImageUrl;
  final String fallbackCoverAssetPath;
  final VoidCallback onContinue;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _dashboardSecondary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _dashboardPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverImageUrl != null &&
                      coverImageUrl!.startsWith('http'))
                    Image.network(
                      coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        fallbackCoverAssetPath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (coverImageUrl == null)
                    Image.asset(fallbackCoverAssetPath, fit: BoxFit.cover),
                  Center(
                    child: isPlaying
                        ? const Icon(
                            Icons.graphic_eq_rounded,
                            color: _dashboardPrimary,
                            size: 24,
                          )
                        : const Icon(
                            Icons.pause_rounded,
                            color: _dashboardPrimary,
                            size: 24,
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sesión activa',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _dashboardPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _dashboardForeground,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _dashboardMuted,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: _dashboardMuted,
            tooltip: 'Cerrar sesión',
          ),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: _dashboardPrimary,
              foregroundColor: _dashboardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: Text(
              'Abrir',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onItemTapped;
  final Color? backgroundColor;

  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onItemTapped,
    this.backgroundColor,
  });

  static const _icons = [
    Icons.home_rounded,
    Icons.favorite_border_rounded,
    Icons.emergency_outlined,
    Icons.person_outline_rounded,
  ];
  static const _labels = ['Inicio', 'Salud', 'SOS', 'Perfil'];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Builder(
          builder: (context) {
            return Container(
              height: 88,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (backgroundColor ?? _dashboardBackground).withValues(
                  alpha: 0.82,
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.42),
                    blurRadius: 36,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_icons.length, (i) {
                  final bool isActive = i == selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onItemTapped(i),
                      behavior: HitTestBehavior.opaque,
                      child: Semantics(
                        label: 'Pestaña ${_labels[i]}',
                        selected: isActive,
                        button: true,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? (backgroundColor != null &&
                                              backgroundColor!
                                                      .computeLuminance() <
                                                  0.1
                                          ? _dashboardPrimary.withValues(
                                              alpha: 0.85,
                                            )
                                          : _dashboardPrimary)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _icons[i],
                                size: 22,
                                color: isActive
                                    ? (backgroundColor != null &&
                                              backgroundColor!
                                                      .computeLuminance() <
                                                  0.1
                                          ? Colors.white
                                          : _dashboardBackground)
                                    : _dashboardMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _labels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isActive
                                    ? _dashboardForeground
                                    : _dashboardMuted,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroRecommendationCard extends StatelessWidget {
  final AudioSession session;
  final VoidCallback onTap;
  final String categoryLabel;
  final String durationLabel;

  const _HeroRecommendationCard({
    required this.session,
    required this.onTap,
    required this.categoryLabel,
    required this.durationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final String fallbackAsset = session.category.coverImagePath;
    final String? coverUrl = session.coverImageUrl;

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _dashboardCard,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: _dashboardPrimary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: coverUrl != null && coverUrl.startsWith('http')
                  ? Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Image.asset(fallbackAsset, fit: BoxFit.cover),
                    )
                  : Image.asset(fallbackAsset, fit: BoxFit.cover),
            ),

            // Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      'ESTRENO RECOMENDADO',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    session.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        categoryLabel.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        width: 3,
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: const BoxDecoration(
                          color: Colors.white70,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        durationLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Play Button Overlay
            Positioned(
              bottom: 20,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: _dashboardPrimary,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),

            // Full-card InkWell
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryRecommendationCard extends StatelessWidget {
  final AudioSession session;
  final VoidCallback onTap;
  final String categoryLabel;
  final String durationLabel;

  const _SecondaryRecommendationCard({
    required this.session,
    required this.onTap,
    required this.categoryLabel,
    required this.durationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final String fallbackAsset = session.category.coverImagePath;
    final String? coverUrl = session.coverImageUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                width: 140,
                decoration: BoxDecoration(
                  color: _dashboardSecondary.withValues(alpha: 0.46),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: coverUrl != null && coverUrl.startsWith('http')
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(fallbackAsset, fit: BoxFit.cover),
                        )
                      : Image.asset(fallbackAsset, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _dashboardForeground,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$categoryLabel · $durationLabel',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _dashboardMuted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
