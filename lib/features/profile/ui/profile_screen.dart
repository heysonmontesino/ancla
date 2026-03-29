import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/prefs_keys.dart';
import '../../../core/theme.dart';
import '../../onboarding/splash_screen.dart';
import '../../sessions/controllers/session_playback_controller.dart';
import '../controllers/profile_stats_controller.dart';
import '../data/emergency_contact_repository.dart';
import '../data/models/ai_tone_preference.dart';
import '../data/models/emergency_contact.dart';
import '../data/profile_preferences_repository.dart';
import '../../ai_chat/presentation/asistente_emocional_screen.dart';
import '../../auth/data/auth_repository.dart';
import 'widgets/contact_edit_dialog.dart';

const Color _card = Colors.white;
const Color _primary = AppColors.primary;
const Color _fg = AppColors.textDark;
const Color _muted = AppColors.textMuted;
const Color _destructive = Color(0xFFDC2626);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Future<ProfileStats> _statsFuture;
  AiTonePreference _selectedTone = AiTonePreference.empathic;

  @override
  void initState() {
    super.initState();
    _statsFuture = ProfileStatsController.load();
    unawaited(_loadTone());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
    });
  }

  Future<void> _loadTone() async {
    final tone = await ProfilePreferencesRepository.getAiTone();
    if (mounted) setState(() => _selectedTone = tone);
  }

  String _displayName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Invitado'; // More accurate for no session

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) {
        return localPart
            .split(RegExp(r'[._-]+'))
            .where((p) => p.isNotEmpty)
            .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
            .join(' ');
      }
    }
    return 'Usuario';
  }

  String? _email() => FirebaseAuth.instance.currentUser?.email;

  Future<void> _handleToneChange(AiTonePreference tone) async {
    setState(() => _selectedTone = tone);
    await ProfilePreferencesRepository.saveAiTone(tone);
  }

  Future<void> _handleResetConsent() async {
    await ProfilePreferencesRepository.resetAiChatConsent();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Consentimiento restablecido. Se solicitará de nuevo al abrir el asistente.',
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Cerrar sesión',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '¿Seguro que quieres salir? Tendrás que iniciar sesión de nuevo.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: _destructive),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await SessionPlaybackController.instance.closeSession();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.aiChatConsentAccepted);
    await prefs.remove(PrefsKeys.aiTonePreference);

    try {
      await AuthRepository.signOut();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cerrar la sesión: $e'),
          backgroundColor: _destructive,
        ),
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Eliminar cuenta y datos',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: Colors.redAccent,
          ),
        ),
        content: Text(
          'Esta acción es IRREVERSIBLE. Se eliminarán permanentemente:\n\n'
          '• Tu perfil y racha de progreso\n'
          '• Historial de check-ins diarios\n'
          '• Contactos de emergencia\n'
          '• Registros de uso de SOS\n\n'
          '¿Deseas continuar con el borrado?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.plusJakartaSans(
                color: _muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'ELIMINAR TODO',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // 1. Clear local session data in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(PrefsKeys.aiChatConsentAccepted);
      await prefs.remove(PrefsKeys.aiTonePreference);

      // 2. Perform remote data and account deletion
      await AuthRepository.deleteAccount();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Ocurrió un error al eliminar la cuenta.';
      if (e.code == 'requires-recent-login') {
        message =
            'Por seguridad, debes cerrar sesión y volver a entrar antes de eliminar tu cuenta.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName();
    final email = _email();
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      color: AppColors.ivory,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverSafeArea(
            top: true,
            bottom: false,
            sliver: SliverToBoxAdapter(child: SizedBox(height: 20)),
          ),

          // ── Identidad ────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _IdentitySection(
                initial: initial,
                displayName: displayName,
                email: email,
                hasUser: AuthRepository.hasUser,
                isAnonymous: AuthRepository.isAnonymous,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Estadísticas ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: FutureBuilder<ProfileStats>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? ProfileStats.empty;
                  return _StatsSection(stats: stats);
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Círculo de Confianza ──────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder<List<EmergencyContact>>(
                stream: EmergencyContactRepository.watchContacts(),
                builder: (context, snapshot) {
                  final contacts = snapshot.data ?? [];
                  return _EmergencyContactsSection(
                    contacts: contacts,
                    onAdd: () => showContactEditDialog(context),
                    onDelete: (id) =>
                        EmergencyContactRepository.deleteContact(id),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Preferencias de IA ────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _AiPreferencesSection(
                selectedTone: _selectedTone,
                onToneChanged: _handleToneChange,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Chat de apoyo emocional ───────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _SettingsTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Chat de apoyo emocional (Beta)',
                subtitle: 'Apoyo guiado por IA, disponible cuando lo necesitas.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AsistenteEmocionalScreen(),
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Ajustes ───────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _SettingsSection(
                onResetConsent: () {
                  unawaited(_handleResetConsent());
                },
                onSignOut: () {
                  unawaited(_handleSignOut());
                },
                onDeleteAccount: () {
                  unawaited(_handleDeleteAccount());
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 132)),
        ],
      ),
    );
  }
}

// ─── Identity ────────────────────────────────────────────────────────────────

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({
    required this.initial,
    required this.displayName,
    this.email,
    required this.hasUser,
    required this.isAnonymous,
  });

  final String initial;
  final String displayName;
  final String? email;
  final bool hasUser;
  final bool isAnonymous;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _primary,
          ),
          child: Center(
            child: Text(
              initial,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _fg,
                  letterSpacing: -0.5,
                ),
              ),
              if (email != null) ...[
                const SizedBox(height: 4),
                Text(
                  email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
              ],
              if (isAnonymous) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Vinculación con Google disponible próximamente',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.link_outlined,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Cuenta temporal · Vincula para no perder tus datos',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (!hasUser) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sin sesión activa',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Stats ────────────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats});

  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu progreso',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _fg,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: _muted.withValues(alpha: 0.5),
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'Estadísticas no disponibles',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No pudimos conectar con tus datos de actividad habitual. Inténtalo de nuevo más tarde.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu progreso',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _fg,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _StatChip(
              emoji: '🔥',
              value: '${stats.checkInStreak}',
              label: 'días de\nracha',
            ),
            const SizedBox(width: 10),
            _StatChip(
              emoji: '💬',
              value: '${stats.sessionFeedbackCount}',
              label: 'sesiones\ncon feedback',
            ),
            const SizedBox(width: 10),
            _StatChip(
              emoji: '🆘',
              value: '${stats.sosActivations}',
              label: 'SOS\nesta semana',
            ),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _fg,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _muted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Emergency Contacts ───────────────────────────────────────────────────────

class _EmergencyContactsSection extends StatelessWidget {
  const _EmergencyContactsSection({
    required this.contacts,
    required this.onAdd,
    required this.onDelete,
  });

  final List<EmergencyContact> contacts;
  final VoidCallback onAdd;
  final void Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Círculo de confianza',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _fg,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Personas a contactar en momentos difíciles',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _muted,
          ),
        ),
        const SizedBox(height: 14),
        if (contacts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.people_outline_rounded, color: _muted, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Aún no has agregado contactos',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
              ],
            ),
          )
        else
          ...contacts.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ContactTile(contact: c, onDelete: () => onDelete(c.id)),
            ),
          ),
        if (contacts.length < 2) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar contacto'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onDelete});

  final EmergencyContact contact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: _primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            color: _muted,
            iconSize: 20,
            tooltip: 'Eliminar contacto',
          ),
        ],
      ),
    );
  }
}

// ─── AI Preferences ───────────────────────────────────────────────────────────

class _AiPreferencesSection extends StatelessWidget {
  const _AiPreferencesSection({
    required this.selectedTone,
    required this.onToneChanged,
  });

  final AiTonePreference selectedTone;
  final Future<void> Function(AiTonePreference) onToneChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asistente emocional',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _fg,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tono del asistente',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _fg,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<AiTonePreference>(
                segments: AiTonePreference.values
                    .map(
                      (t) => ButtonSegment<AiTonePreference>(
                        value: t,
                        label: Text(t.label),
                      ),
                    )
                    .toList(),
                selected: {selectedTone},
                onSelectionChanged: (selection) {
                  unawaited(onToneChanged(selection.first));
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: _primary,
                  selectedForegroundColor: Colors.white,
                  maximumSize: const Size(double.infinity, 44),
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                selectedTone.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Settings ─────────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.onResetConsent,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final VoidCallback onResetConsent;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ajustes',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _fg,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        _SettingsTile(
          icon: Icons.restart_alt_rounded,
          title: 'Restablecer consentimiento IA',
          subtitle: 'El aviso de privacidad se mostrará de nuevo.',
          onTap: onResetConsent,
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.logout_rounded,
          title: 'Cerrar sesión',
          onTap: onSignOut,
          isDestructive: false,
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.delete_forever_rounded,
          title: 'Eliminar cuenta y datos',
          subtitle: 'Borrado permanente e irreversible.',
          onTap: onDeleteAccount,
          isDestructive: true,
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? _destructive : _primary;
    final bgColor = isDestructive
        ? _destructive.withValues(alpha: 0.06)
        : _card;
    final borderColor = isDestructive
        ? _destructive.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.05);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDestructive ? 0.12 : 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDestructive
                    ? _destructive.withValues(alpha: 0.5)
                    : _muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
