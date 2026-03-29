import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
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
import '../health/ui/health_log_view.dart';
import '../games/ui/games_screen.dart';
import '../profile/ui/profile_screen.dart';
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

  String _currentUserName() {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final String? email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      final String localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) {
        return localPart
            .split(RegExp(r'[._-]+'))
            .where((part) => part.isNotEmpty)
            .map(_capitalizeWord)
            .join(' ');
      }
    }

    return 'Usuario';
  }

  String _capitalizeWord(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }



  @override
  Widget build(BuildContext context) {
    final SessionPlaybackController playback =
        SessionPlaybackController.instance;
    final DateTime now = DateTime.now();
    final String greeting = _greetingForHour(now.hour);
    final String userName = _currentUserName();

    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final bool hasPlaybackSession = playback.hasCurrentSession;
        final AudioSession? currentSession = playback.currentSession;
        
        final String sessionMessage = hasPlaybackSession && currentSession != null
            ? (playback.isPlaybackActive
                ? 'Tu audio sigue activo en segundo plano.'
                : 'Tu sesion pausada esta lista para continuar.')
            : 'Explora la biblioteca para comenzar una sesion.';

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
                                  child: SizedBox(height: 20),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              greeting,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: _dashboardMuted,
                                                    letterSpacing: 0.2,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              userName,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 34,
                                                    fontWeight: FontWeight.w700,
                                                    color: _dashboardForeground,
                                                    letterSpacing: -1.2,
                                                    height: 1.0,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              sessionMessage,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: _dashboardMuted,
                                                    height: 1.4,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: _dashboardCard,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.06,
                                            ),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _dashboardPrimary
                                                  .withValues(alpha: 0.10),
                                              blurRadius: 24,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.person_outline_rounded,
                                          color: _dashboardPrimary,
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 30),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
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
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: const Color(0xFF4CAF7D).withValues(alpha: 0.3),
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
                                                  scale: 1.0 + (_sosPulse.value * 0.1),
                                                  child: Container(
                                                    width: 120 * (1.0 + (_sosPulse.value * 0.2)),
                                                    height: 120 * (1.0 + (_sosPulse.value * 0.2)),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      gradient: RadialGradient(
                                                        colors: [
                                                          const Color(0xFF4CAF7D).withValues(alpha: 0.1 * (1.0 - _sosPulse.value)),
                                                          const Color(0xFF4CAF7D).withValues(alpha: 0.0),
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
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF4CAF7D).withValues(alpha: 0.15),
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
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        '¿Necesitas ayuda ahora?',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w700,
                                                          color: _sosForeground,
                                                          letterSpacing: -0.3,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Línea 106 · atención inmediata',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: _sosForeground.withValues(alpha: 0.5),
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
                                                    borderRadius: BorderRadius.circular(16),
                                                    child: Ink(
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF4CAF7D).withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(16),
                                                        border: Border.all(
                                                          color: const Color(0xFF4CAF7D).withValues(alpha: 0.4),
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        'Llamar 106',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                          color: const Color(0xFF4CAF7D),
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
                                child: SizedBox(height: 28),
                              ),
                              if (hasPlaybackSession && currentSession != null)
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 18,
                                      ),
                                      child: _ActiveSessionCard(
                                        title: currentSession.title,
                                        subtitle:
                                            '${_categoryLabel(currentSession.category).toUpperCase()} · ${_formatMinutes(currentSession.durationSeconds)}',
                                        isPlaying: playback.isPlaybackActive,
                                        coverImageUrl:
                                            currentSession.coverImageUrl,
                                        fallbackCoverAssetPath:
                                            currentSession.category.coverImagePath,
                                        onContinue: () =>
                                            _openAudioSession(currentSession),
                                        onClose: _closeActiveSession,
                                      ),
                                    ),
                                  ),
                                ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
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
                                      const SizedBox(height: 18),
                                      StreamBuilder<List<AudioSession>>(
                                        stream: _featuredSessionsStream,
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                              child: Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                            );
                                          }

                                          if (snapshot.hasError) {
                                            return Text(
                                              'La biblioteca no esta disponible en este momento.',
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

                                          return Column(
                                            children: sessions
                                                .map(
                                                  (session) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 12,
                                                        ),
                                                    child: _RecommendedSessionTile(
                                                      title: session.title,
                                                      category: _categoryLabel(
                                                        session.category,
                                                      ),
                                                      durationLabel:
                                                          _formatMinutes(
                                                            session
                                                                .durationSeconds,
                                                          ),
                                                      coverImageUrl:
                                                          session.coverImageUrl,
                                                      fallbackCoverAssetPath:
                                                          session
                                                              .category
                                                              .coverImagePath,
                                                      onTap: () =>
                                                          _openAudioSession(
                                                            session,
                                                          ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 14),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
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
                                child: SizedBox(height: 14),
                              ),

                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height:
                                      100 + MediaQuery.of(context).padding.bottom,
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
                  if (coverImageUrl != null && coverImageUrl!.startsWith('http'))
                    Image.network(
                      coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Image.asset(
                            fallbackCoverAssetPath,
                            fit: BoxFit.cover,
                          ),
                    ),
                  if (coverImageUrl == null)
                    Image.asset(
                      fallbackCoverAssetPath,
                      fit: BoxFit.cover,
                    ),
                  Center(
                    child: isPlaying
                        ? const Icon(Icons.graphic_eq_rounded,
                            color: _dashboardPrimary, size: 24)
                        : const Icon(Icons.pause_rounded,
                            color: _dashboardPrimary, size: 24),
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

class _RecommendedSessionTile extends StatelessWidget {
  const _RecommendedSessionTile({
    required this.title,
    required this.category,
    required this.durationLabel,
    this.coverImageUrl,
    required this.fallbackCoverAssetPath,
    required this.onTap,
  });

  final String title;
  final String category;
  final String durationLabel;
  final String? coverImageUrl;
  final String fallbackCoverAssetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _dashboardSecondary.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _dashboardCard,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: coverImageUrl != null &&
                          coverImageUrl!.startsWith('http')
                      ? Image.network(
                          coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                            fallbackCoverAssetPath,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          fallbackCoverAssetPath,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _dashboardForeground,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${category.toUpperCase()} · $durationLabel',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _dashboardMuted,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _dashboardPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _dashboardPrimary.withValues(alpha: 0.18),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: _dashboardBackground,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
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
                                            backgroundColor!.computeLuminance() <
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
                                            backgroundColor!.computeLuminance() <
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
