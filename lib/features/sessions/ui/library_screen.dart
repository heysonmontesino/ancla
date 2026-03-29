import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../core/ui/widgets/organic_background.dart';
import '../../home/emergency_screen.dart';
import '../controllers/session_playback_controller.dart';
import '../data/firestore_audio_repository.dart';
import '../models/audio_session.dart';
import 'session_player_screen.dart';

const Color _libraryBackground = AppColors.ivory;
const Color _libraryForeground = AppColors.textDark;
const Color _libraryPrimary = AppColors.primary;
const Color _librarySecondary = AppColors.sageLight;
const Color _libraryCard = Colors.white;
const Color _libraryMuted = AppColors.textMuted;
const String _premiumRequiredMessage =
    'Esta sesión es exclusiva para usuarios premium.';

Future<bool> _currentUserIsPremium() async {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return false;
  }

  try {
    final IdTokenResult tokenResult = await user.getIdTokenResult();
    final dynamic claim = tokenResult.claims?['isPremium'];

    if (claim is bool) {
      return claim;
    }
    if (claim is num) {
      return claim != 0;
    }
    if (claim is String) {
      return claim.toLowerCase() == 'true';
    }
  } catch (_) {
    return false;
  }

  return false;
}

Future<bool> _ensurePremiumAccess(
  BuildContext context,
  AudioSession session,
) async {
  if (!session.isPremium) {
    return true;
  }

  final bool isPremiumUser = await _currentUserIsPremium();
  if (isPremiumUser) {
    return true;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(_premiumRequiredMessage),
      ),
    );
  }
  return false;
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  static PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 90,
      leadingWidth: 72,
      leading: Padding(
        padding: const EdgeInsets.only(left: 20, top: 8),
        child: _HeaderIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
      ),
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(top: 8, right: 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Explorar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: _libraryForeground,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Biblioteca curada de protocolos y sesiones',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _libraryMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const _HeaderIconButton(icon: Icons.search_rounded),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _libraryBackground,
      appBar: _buildAppBar(context),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'sos_library',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const EmergencyScreen(),
          ),
        ),
        backgroundColor: const Color(0xFF7B1A1A),
        child: const Icon(
          Icons.emergency_outlined,
          color: Colors.white,
          size: 18,
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: const OrganicBackgroundGradient(child: SizedBox.expand()),
          ),
          StreamBuilder<List<AudioSession>>(
            stream: FirestoreAudioRepository.watchSessions(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorBody(message: snapshot.error.toString());
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingBody();
              }

              final sessions = snapshot.data ?? [];
              if (sessions.isEmpty) {
                return const _EmptyBody();
              }

              return _LibraryContent(sessions: sessions);
            },
          ),
        ],
      ),
    );
  }
}

class _LibraryContent extends StatefulWidget {
  final List<AudioSession> sessions;

  const _LibraryContent({required this.sessions});

  @override
  State<_LibraryContent> createState() => _LibraryContentState();
}

class _LibraryContentState extends State<_LibraryContent> {
  SessionCategory? _selectedCategory;

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: SessionCategory.values.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final bool isAll = index == 0;
          final SessionCategory? category = isAll
              ? null
              : SessionCategory.values[index - 1];
          final bool isSelected = _selectedCategory == category;
          final String label = isAll ? 'Todos' : category!.displayName;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? _libraryPrimary
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? _libraryPrimary
                      : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? _libraryBackground
                      : _libraryForeground.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SessionPlaybackController playback =
        SessionPlaybackController.instance;
    final Map<SessionCategory, List<AudioSession>> grouped = {};

    final categoriesToDisplay = _selectedCategory != null
        ? [_selectedCategory!]
        : SessionCategory.values;

    for (final category in categoriesToDisplay) {
      final items = widget.sessions
          .where((s) => s.category == category)
          .toList();
      if (items.isNotEmpty) {
        grouped[category] = items;
      }
    }

    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) => CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          if (playback.hasCurrentSession && playback.currentSession != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                child: _ResumeSessionBanner(
                  session: playback.currentSession!,
                  isPlaying: playback.isPlaybackActive,
                  onContinue: () {
                    unawaited(() async {
                      final AudioSession session = playback.currentSession!;
                      final bool allowed = await _ensurePremiumAccess(
                        context,
                        session,
                      );
                      if (!allowed || !context.mounted) {
                        return;
                      }

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              SessionPlayerScreen(session: session),
                        ),
                      );
                    }());
                  },
                  onClose: () => playback.closeSession(),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildFilterChips(),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final SessionCategory category = grouped.keys.elementAt(index);
              final List<AudioSession> items = grouped[category]!;
              return _CategorySection(category: category, sessions: items);
            }, childCount: grouped.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 36)),
        ],
      ),
    );
  }
}

class _ResumeSessionBanner extends StatelessWidget {
  const _ResumeSessionBanner({
    required this.session,
    required this.isPlaying,
    required this.onContinue,
    required this.onClose,
  });

  final AudioSession session;
  final bool isPlaying;
  final VoidCallback onContinue;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _librarySecondary.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _libraryPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isPlaying ? Icons.graphic_eq_rounded : Icons.pause_rounded,
              color: _libraryPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Continuar sesion',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _libraryPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _libraryForeground,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.category.displayName.toUpperCase()} · ${(session.durationSeconds / 60).ceil()} min',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _libraryMuted,
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
            color: _libraryMuted,
            tooltip: 'Cerrar audio',
          ),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: _libraryPrimary,
              foregroundColor: _libraryBackground,
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

class _CategorySection extends StatelessWidget {
  final SessionCategory category;
  final List<AudioSession> sessions;

  const _CategorySection({required this.category, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              category.displayName.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _libraryMuted,
                letterSpacing: 2.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              category.subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _libraryForeground,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 268,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                return _SessionCard(session: sessions[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final AudioSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final String durationLabel = '${(session.durationSeconds / 60).ceil()} min';

    return Container(
      width: 188,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () async {
            final bool allowed = await _ensurePremiumAccess(context, session);
            if (!allowed || !context.mounted) {
              return;
            }

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SessionPlayerScreen(session: session),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Ink(
                  decoration: BoxDecoration(
                    color: _librarySecondary,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              session.coverImageUrl != null
                                  ? Image.network(
                                      session.coverImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => 
                                          Image.asset(
                                            session.category.coverImagePath,
                                            fit: BoxFit.cover,
                                          ),
                                    )
                                  : Image.asset(
                                      session.category.coverImagePath,
                                      fit: BoxFit.cover,
                                    ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      _libraryBackground.withValues(
                                        alpha: 0.85,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        right: 14,
                        child: Row(
                          children: [
                            _StreamingBadge(isOffline: session.isOffline),
                            const Spacer(),
                            if (session.isPremium)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _libraryPrimary.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _libraryPrimary.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'PRO',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: _libraryPrimary,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 118,
                              height: 118,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  width: 2,
                                ),
                              ),
                            ),
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _libraryPrimary.withValues(alpha: 0.12),
                              ),
                              child: const Icon(
                                Icons.graphic_eq_rounded,
                                color: _libraryForeground,
                                size: 34,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 14,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                session.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _libraryForeground,
                                  letterSpacing: -0.5,
                                  height: 1.05,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _libraryPrimary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _libraryPrimary.withValues(
                                      alpha: 0.20,
                                    ),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: _libraryBackground,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${session.categoryDisplay.toUpperCase()} · $durationLabel',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _libraryMuted,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamingBadge extends StatelessWidget {
  final bool isOffline;

  const _StreamingBadge({required this.isOffline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isOffline
            ? Colors.white.withValues(alpha: 0.08)
            : _libraryPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isOffline
              ? Colors.white.withValues(alpha: 0.08)
              : _libraryPrimary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOffline ? Icons.download_done_rounded : Icons.cloud_rounded,
            size: 11,
            color: isOffline ? _libraryForeground : _libraryPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            isOffline ? 'OFFLINE' : 'STREAM',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isOffline ? _libraryForeground : _libraryPrimary,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _libraryCard,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Icon(icon, color: _libraryPrimary, size: 22),
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const _CenteredShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _libraryPrimary,
            ),
          ),
          SizedBox(height: 22),
          _StateTitle(text: 'Actualizando biblioteca clínica...'),
          SizedBox(height: 8),
          _StateSubtitle(text: 'Conectando con el servidor'),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return const _CenteredShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StateIcon(icon: Icons.library_music_outlined),
          SizedBox(height: 22),
          _StateTitle(text: 'Biblioteca en preparación'),
          SizedBox(height: 8),
          _StateSubtitle(text: 'Las sesiones estarán disponibles en breve.'),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;

  const _ErrorBody({required this.message});

  @override
  Widget build(BuildContext context) {
    return const _CenteredShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StateIcon(icon: Icons.cloud_off_rounded),
          SizedBox(height: 22),
          _StateTitle(text: 'No se pudo cargar la biblioteca'),
          SizedBox(height: 8),
          _StateSubtitle(text: 'Verifica tu conexión e intenta de nuevo.'),
        ],
      ),
    );
  }
}

class _CenteredShell extends StatelessWidget {
  final Widget child;

  const _CenteredShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: child,
      ),
    );
  }
}

class _StateIcon extends StatelessWidget {
  final IconData icon;

  const _StateIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: _libraryCard,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Icon(icon, size: 34, color: _libraryPrimary),
    );
  }
}

class _StateTitle extends StatelessWidget {
  final String text;

  const _StateTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _libraryForeground,
        letterSpacing: -0.6,
      ),
    );
  }
}

class _StateSubtitle extends StatelessWidget {
  final String text;

  const _StateSubtitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _libraryMuted,
        height: 1.45,
      ),
    );
  }
}
