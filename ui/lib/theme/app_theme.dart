import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand & Accents
  static const Color slateNavyDark = Color(0xFF0A192F);
  static const Color slateNavy = Color(0xFF0F172A);
  static const Color slateNavyLight = Color(0xFF1E293B);

  static const Color medicalTeal = Color(0xFF0D9488);
  static const Color medicalTealLight = Color(0xFF14B8A6);
  static const Color medicalTealDark = Color(0xFF0F766E);

  static const Color cyberCyan = Color(0xFF06B6D4);
  static const Color cyberCyanLight = Color(0xFF22D3EE);

  // Triage Severities (WHO IMCI)
  static const Color emergencyRed = Color(0xFFEF4444);
  static const Color emergencyRedDark = Color(0xFFDC2626);
  static const Color emergencyRedBg = Color(0xFFFEF2F2);
  static const Color emergencyRedBorder = Color(0xFFFECACA);

  static const Color clinicalAmber = Color(0xFFF59E0B);
  static const Color clinicalAmberDark = Color(0xFFD97706);
  static const Color clinicalAmberBg = Color(0xFFFFFBEB);
  static const Color clinicalAmberBorder = Color(0xFFFDE68A);

  static const Color safeEmerald = Color(0xFF10B981);
  static const Color safeEmeraldDark = Color(0xFF059669);
  static const Color safeEmeraldBg = Color(0xFFECFDF5);
  static const Color safeEmeraldBorder = Color(0xFFA7F3D0);

  // Neutral & Surfaces
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Colors.white;
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFF1F5F9);

  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [medicalTealDark, medicalTeal, cyberCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient redDangerGradient = LinearGradient(
    colors: [Color(0xFFB91C1C), emergencyRed, Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient yellowWarningGradient = LinearGradient(
    colors: [Color(0xFFB45309), clinicalAmber, Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenSafeGradient = LinearGradient(
    colors: [Color(0xFF047857), safeEmerald, Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.medicalTeal,
        primary: AppColors.medicalTeal,
        secondary: AppColors.cyberCyan,
        surface: AppColors.surfaceWhite,
      ),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        displayLarge: GoogleFonts.cairo(color: AppColors.textMain, fontWeight: FontWeight.w900, fontSize: 30),
        displayMedium: GoogleFonts.cairo(color: AppColors.textMain, fontWeight: FontWeight.w800, fontSize: 24),
        titleLarge: GoogleFonts.cairo(color: AppColors.textMain, fontWeight: FontWeight.w800, fontSize: 18),
        titleMedium: GoogleFonts.cairo(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 15),
        titleSmall: GoogleFonts.cairo(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
        bodyLarge: GoogleFonts.cairo(color: AppColors.textMain, fontWeight: FontWeight.w600, fontSize: 14),
        bodyMedium: GoogleFonts.cairo(color: AppColors.textMuted, fontWeight: FontWeight.w500, fontSize: 12),
        bodySmall: GoogleFonts.cairo(color: AppColors.textLight, fontWeight: FontWeight.w500, fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.textMain,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(color: AppColors.textMain, fontWeight: FontWeight.w800, fontSize: 18),
        iconTheme: const IconThemeData(color: AppColors.textMain),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.medicalTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.medicalTeal,
          side: const BorderSide(color: AppColors.medicalTeal, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.medicalTeal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.cairo(color: AppColors.textMuted, fontSize: 14),
        hintStyle: GoogleFonts.cairo(color: AppColors.textLight, fontSize: 13),
      ),
    );
  }
}
