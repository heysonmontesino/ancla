import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../ai_chat/data/asistente_emocional_service.dart';

enum AiAssistantEntryAction {
  openAssistant,
  openJournal,
  openLibrary,
  openEmergency,
}

class AiAssistantEntryResult {
  final AiAssistantEntryAction action;
  final AiAssistantStatus status;

  const AiAssistantEntryResult({required this.action, required this.status});
}

class AiAssistantEntrySheet extends StatefulWidget {
  const AiAssistantEntrySheet({super.key});

  @override
  State<AiAssistantEntrySheet> createState() => _AiAssistantEntrySheetState();
}

class _AiAssistantEntrySheetState extends State<AiAssistantEntrySheet> {
  AiAssistantStatus? _status;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final service = AsistenteEmocionalService();
    final status = await service.checkAvailability();
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              _buildLoadingContent()
            else if (_status == AiAssistantStatus.available)
              _buildAvailableContent()
            else
              _buildUnavailableContent(_status!),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Preparando asistente...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 100), // Espacio para mantener altura similar
      ],
    );
  }

  Widget _buildAvailableContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBadge('BETA GUIADA'),
        const SizedBox(height: 18),
        Text(
          'Asistente de apoyo emocional',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.7,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Puedes usarlo para poner en palabras lo que sientes, ordenar ideas y recibir una orientación inicial con tono cuidado. No sustituye ayuda urgente ni atención profesional de emergencia.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        const _InfoCard(
          icon: Icons.favorite_border_rounded,
          title: 'Qué sí puede ayudarte a hacer',
          body:
              'Hablar un momento, bajar intensidad emocional y descubrir una sesión guiada que te acompañe.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.health_and_safety_outlined,
          title: 'Importante',
          body:
              'Si estás en crisis, con riesgo inminente o necesitas atención inmediata, usa SOS o comunícate con una línea de emergencia.',
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(
              AiAssistantEntryResult(
                action: AiAssistantEntryAction.openAssistant,
                status: _status!,
              ),
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Abrir asistente'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(
              AiAssistantEntryResult(
                action: AiAssistantEntryAction.openEmergency,
                status: _status!,
              ),
            ),
            icon: const Icon(Icons.emergency_outlined),
            label: const Text('Necesito ayuda inmediata'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textDark,
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnavailableContent(AiAssistantStatus status) {
    String title = 'Asistente en mantenimiento';
    String description =
        'Estamos terminando esta experiencia para que sea útil y segura. Por ahora el asistente no está disponible.';

    if (status == AiAssistantStatus.notConfigured) {
      title = 'Asistente en activación';
      description =
          'Esta función se activará gradualmente en tu región. Estamos trabajando para traértela pronto.';
    } else if (status == AiAssistantStatus.degraded) {
      title = 'Asistente saturado';
      description =
          'Estamos recibiendo muchas consultas. Por favor, intenta de nuevo en unos minutos o usa estas alternativas.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBadge(status == AiAssistantStatus.notConfigured
            ? 'PRÓXIMAMENTE'
            : 'MANTENIMIENTO'),
        const SizedBox(height: 18),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.7,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _InfoCard(
          icon: Icons.history_edu_rounded,
          title: 'Mientras tanto puedes apoyarte en',
          body:
              'Tu bitácora diaria para expresar emociones, las sesiones guiadas para calmarte o SOS si es urgente.',
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(
              AiAssistantEntryResult(
                action: AiAssistantEntryAction.openJournal,
                status: _status!,
              ),
            ),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Registrar en Bitácora'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(
              AiAssistantEntryResult(
                action: AiAssistantEntryAction.openLibrary,
                status: _status!,
              ),
            ),
            icon: const Icon(Icons.library_music_outlined),
            label: const Text('Ver sesiones guiadas'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textDark,
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(
              AiAssistantEntryResult(
                action: AiAssistantEntryAction.openEmergency,
                status: _status!,
              ),
            ),
            child: const Text('Ir a SOS'),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE4D6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
