import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../home/dashboard_screen.dart';
import '../auth/data/auth_repository.dart';
import 'onboarding_screen.dart';
import 'onboarding_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    unawaited(_bootstrapAndNavigate());
  }

  Future<void> _bootstrapAndNavigate() async {
    try {
      // Parallelize splash delay and auth initialization
      await Future.wait([
        Future<void>.delayed(const Duration(milliseconds: 3200)),
        AuthRepository.signInSilently(),
      ]);
    } catch (_) {
      // Bootstrap failure is handled by AuthRepository or downstream isAnonymous/hasUser checks
    }

    await _navigateToDashboard();
  }

  Future<void> _navigateToDashboard() async {
    if (!mounted || _hasNavigated) return;

    final onboardingDone = await OnboardingService.isComplete();
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: onboardingDone
                ? const DashboardScreen()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundDarkness = Color(0xFF030406);
    return Scaffold(
      backgroundColor: backgroundDarkness,
      body: Stack(
        children: [
          // Night-to-dawn fade
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      backgroundDarkness,
                      Color.lerp(
                            backgroundDarkness,
                            AppColors.ivory,
                            _fadeAnimation.value * 0.3,
                          ) ??
                          backgroundDarkness,
                    ],
                  ),
                ),
              );
            },
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: const Hero(tag: 'app_logo_orb', child: _LogoOrb()),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoOrb extends StatelessWidget {
  const _LogoOrb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.2, -0.2),
          radius: 1.0,
          colors: [
            Color(0xFFE8E3F2), // Lighter lavender
            Color(0xFFD6E2E8), // Soft blue
            AppColors.sageLight, // Sage
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.sageLight.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
    );
  }
}
