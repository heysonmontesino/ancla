import 'dart:ui';
import 'package:flutter/material.dart';

import '../../theme.dart';

class OrganicBackgroundGradient extends StatelessWidget {
  final Widget child;

  const OrganicBackgroundGradient({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Ivory background from theme
        Container(color: AppColors.ivory),
        // Soft gradient overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.sageLight.withValues(alpha: 0.8), // Sage
                  AppColors.ivory,
                ],
                stops: const [0.0, 0.4],
              ),
            ),
          ),
        ),
        // Faint lavender organic blur at top right
        Positioned(
          top: -100,
          right: -80,
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(
                width: 280,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE8E3F2), // Lavender noche from your category colors
                ),
              ),
            ),
          ),
        ),
        // Soft blue / sage blur at bottom left for balance
        Positioned(
          bottom: -100,
          left: -80,
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE3EBF2), // Azul muted
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
