import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData darkTheme({bool useArabicFont = false}) {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = useArabicFont
        ? base.textTheme.apply(
            fontFamily: 'Arial',
            bodyColor: AppColors.textLight,
            displayColor: AppColors.textLight,
          )
        : GoogleFonts.rubikTextTheme(base.textTheme);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.deepSpace,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.hotPink,
        secondary: AppColors.neonGreen,
        surface: AppColors.card,
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: (textTheme.headlineLarge ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.textLight,
        ),
        titleLarge: (textTheme.titleLarge ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
        ),
        bodyLarge: (textTheme.bodyLarge ?? const TextStyle()).copyWith(
          color: AppColors.textLight,
        ),
        bodyMedium: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: AppColors.textMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.hotPink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF4D6D), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF4D6D), width: 1.6),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        errorStyle: const TextStyle(
          color: Color(0xFFFF4D6D),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
