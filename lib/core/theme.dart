import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color Palette ──────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  /// #1F3D2B — Verde bosque profundo (Primary)
  static const Color primary = Color(0xFF1F3D2B);

  /// #3ECF8E — Menta vibrante (Accent)
  static const Color accent = Color(0xFF3ECF8E);

  /// #F7F5EF — Marfil cálido (Light background)
  static const Color ivory = Color(0xFFF7F5EF);

  /// #EAF4EE — Salvia suave (Card surface light)
  static const Color sageLight = Color(0xFFEAF4EE);

  /// #121212 — Negro absoluto (Dark background)
  static const Color black = Color(0xFF121212);

  /// Text / dark mode
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textCream = Color(0xFFF5F0E8);

  /// Glass layer
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x26FFFFFF);
}

// ─── Typography ─────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  static TextTheme _buildTextTheme(Color bodyColor) {
    return TextTheme(
      // Display — Plus Jakarta Sans Bold
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 42,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        color: bodyColor,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: bodyColor,
      ),
      displaySmall: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: bodyColor,
      ),

      // Headline — Plus Jakarta Sans SemiBold
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: bodyColor,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: bodyColor,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: bodyColor,
      ),

      // Title — Plus Jakarta Sans Medium
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: bodyColor,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: bodyColor,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: bodyColor,
      ),

      // Body — Plus Jakarta Sans
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: bodyColor,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: bodyColor,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        color: bodyColor.withValues(alpha: 0.7),
      ),

      // Label
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: bodyColor,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: bodyColor,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: bodyColor.withValues(alpha: 0.6),
      ),
    );
  }

  static TextTheme get light => _buildTextTheme(AppColors.textDark);
  static TextTheme get dark => _buildTextTheme(Colors.white);
}

// ─── Theme Configurations ────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  // ── Light Theme — Dashboard diario ────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ivory,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.ivory,
        onPrimary: Colors.white,
        onSecondary: AppColors.primary,
        onSurface: AppColors.textDark,
      ),
      textTheme: AppTextStyles.light,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.sageLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      iconTheme: const IconThemeData(color: AppColors.textDark),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textDark),
      ),
    );
  }

  // ── Dark Theme — Zona de Emergencia ───────────────────────────────────────
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.primary,
        surface: AppColors.black,
        onPrimary: AppColors.black,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      textTheme: AppTextStyles.dark,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }
}
