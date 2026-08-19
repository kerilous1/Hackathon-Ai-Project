import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Palette
  static const Color primary = Color(0xFF5A45F5);
  static const Color primaryLight = Color(0xFF7662FA);
  static const Color primaryDark = Color(0xFF452CE0);
  static const Color primaryBg = Color(0xFFF6F5FD);
  static const Color primaryContainer = Color(0xFFEDE9FE);

  // Backgrounds & Surface
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color cardBorder = Color(0xFFEBEBF5);
  static const Color divider = Color(0xFFF1F5F9);

  // Triage Colors
  static const Color triageYellowBg = Color(0xFFFFFBEB);
  static const Color triageYellowBorder = Color(0xFFFDE68A);
  static const Color triageYellowText = Color(0xFFD97706);
  static const Color triageYellowBadge = Color(0xFFF59E0B);

  static const Color triageRedBg = Color(0xFFFEF2F2);
  static const Color triageRedBorder = Color(0xFFFECACA);
  static const Color triageRedText = Color(0xFFDC2626);
  static const Color triageRedBadge = Color(0xFFEF4444);

  static const Color triageGreenBg = Color(0xFFECFDF5);
  static const Color triageGreenBorder = Color(0xFFA7F3D0);
  static const Color triageGreenText = Color(0xFF059669);
  static const Color triageGreenBadge = Color(0xFF10B981);

  // Neutrals & Text
  static const Color textPrimary = Color(0xFF1E1B4B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Chips & Highlights
  static const Color highlightYellow = Color(0xFFFEF08A);
  static const Color chipBg = Color(0xFFF1F5F9);
  static const Color chipSelectedBg = Color(0xFFEDE9FE);
  static const Color chipSelectedText = Color(0xFF5A45F5);
}

class AppTheme {
  static ThemeData get lightTheme {
    final baseFont = GoogleFonts.cairoTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        background: AppColors.background,
      ),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        displayLarge: baseFont.displayLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        displayMedium: baseFont.displayMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        headlineLarge: baseFont.headlineLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: baseFont.headlineMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        titleLarge: baseFont.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        titleMedium: baseFont.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleSmall: baseFont.titleSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        bodyLarge: baseFont.bodyLarge?.copyWith(color: AppColors.textPrimary),
        bodyMedium: baseFont.bodyMedium?.copyWith(color: AppColors.textSecondary),
        bodySmall: baseFont.bodySmall?.copyWith(color: AppColors.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
        ),
      ),
    );
  }
}
