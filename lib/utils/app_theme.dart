import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';
import 'app_spacing.dart';

/// Centralized Theme Factory generating immutable ThemeData instances for the app.
class AppTheme {
  // ==========================================
  // DARK THEME (Primary / Dark-First)
  // ==========================================
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryAccent,
        secondary: AppColors.secondaryAccent,
        surface: AppColors.darkSurface1,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.h1.copyWith(color: AppColors.textLightPrimary),
        titleLarge: AppTextStyles.h2.copyWith(color: AppColors.textLightPrimary),
        titleMedium: AppTextStyles.h3.copyWith(color: AppColors.textLightPrimary),
        bodyLarge: AppTextStyles.bodyL.copyWith(color: AppColors.textLightPrimary),
        bodyMedium: AppTextStyles.bodyM.copyWith(color: AppColors.textLightSecondary),
        labelLarge: AppTextStyles.label.copyWith(color: AppColors.textLightPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: BorderSide(
            color: AppColors.darkSurfaceBorder.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkSurfaceBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ==========================================
  // LIGHT THEME
  // ==========================================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryAccent,
        secondary: AppColors.secondaryAccent,
        surface: AppColors.lightSurface1,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: AppColors.textDarkPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.h1.copyWith(color: AppColors.textDarkPrimary),
        titleLarge: AppTextStyles.h2.copyWith(color: AppColors.textDarkPrimary),
        titleMedium: AppTextStyles.h3.copyWith(color: AppColors.textDarkPrimary),
        bodyLarge: AppTextStyles.bodyL.copyWith(color: AppColors.textDarkPrimary),
        bodyMedium: AppTextStyles.bodyM.copyWith(color: AppColors.textDarkSecondary),
        labelLarge: AppTextStyles.label.copyWith(color: AppColors.textDarkPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: BorderSide(
            color: AppColors.lightSurfaceBorder.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightSurfaceBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
