import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home/dashboard_screen.dart';
import 'onboarding_service.dart';

const String _kPrivacyPolicyUrl =
    'https://pap-respiracion-sos.web.app/privacy';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    await OnboardingService.markComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: const DashboardScreen(),
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(_kPrivacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _OnboardingPage(
                    icon: Icons.shield_outlined,
                    title: 'Tu Espacio Seguro',
                    body:
                        'Bienvenido a Ancla. Este es un lugar diseñado para acompañarte en momentos de tormenta y para cultivar tu calma diaria. Para proteger tu privacidad, hemos creado un acceso anónimo: no necesitamos tu nombre ni tu correo para que empieces a cuidarte. Tus datos de bienestar se guardan de forma privada en tu dispositivo y en nuestra nube segura.',
                  ),
                  _OnboardingPage(
                    icon: Icons.favorite_outline_rounded,
                    title: 'Registro de Bienestar',
                    body:
                        'Entender cómo te sientes es el primer paso para estar mejor. En Ancla, podrás registrar tu estado emocional y realizar ejercicios de respiración guiada. Al continuar, aceptas que procesemos estos datos de bienestar con el único fin de mostrarte tu progreso. Recuerda: Ancla es una herramienta de acompañamiento, no reemplaza la consulta con un profesional de la salud.',
                    secondaryLabel: 'Leer política de privacidad',
                    onSecondaryTap: _openPrivacyPolicy,
                  ),
                  _OnboardingPage(
                    icon: Icons.phone_outlined,
                    title: 'Soporte en Crisis',
                    body:
                        '¿Te sientes abrumado ahora mismo? Nuestro módulo SOS está listo para ayudarte a regular tu respiración. Sin embargo, si sientes que estás en una emergencia de salud mental, por favor contacta a profesionales de inmediato. En Colombia, puedes marcar la Línea 106 las 24 horas del día.',
                  ),
                ],
              ),
            ),

            // Dots
            _DotsIndicator(
              currentPage: _currentPage,
              count: _pageCount,
            ),

            const SizedBox(height: 20),

            // CTA button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _currentPage == _pageCount - 1
                  ? _PrimaryButton(
                      label: 'Entendido, comenzar',
                      onPressed: _finish,
                    )
                  : _PrimaryButton(
                      label: 'Siguiente',
                      onPressed: _nextPage,
                    ),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

// ── Page content ──────────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    this.secondaryLabel,
    this.onSecondaryTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          // Icon illustration
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.10),
            ),
            child: Icon(icon, size: 32, color: colorScheme.primary),
          ),

          const SizedBox(height: 28),

          // Title
          Text(
            title,
            style: textTheme.displaySmall?.copyWith(
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(height: 16),

          // Body
          Text(
            body,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.75),
              height: 1.6,
            ),
          ),

          // Optional secondary button (privacy policy)
          if (secondaryLabel != null && onSecondaryTap != null) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: onSecondaryTap,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: colorScheme.primary,
                textStyle: textTheme.labelLarge,
              ),
              child: Text(secondaryLabel!),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Dots indicator ────────────────────────────────────────────────────────────

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.currentPage, required this.count});

  final int currentPage;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          width: isActive ? 20 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? colorScheme.primary
                : colorScheme.primary.withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }
}

// ── Primary button ────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
      child: Text(label),
    );
  }
}
