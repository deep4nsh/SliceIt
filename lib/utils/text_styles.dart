import 'package:flutter/material.dart';
import 'colors.dart';

/// Unified Poppins-only typography scale following a minimal 6-level architecture.
class AppTextStyles {
  static const String _fontFamily = 'Poppins';

  // ==========================================
  // MODERN 6-LEVEL TYPOGRAPHY SCALE (Poppins)
  // ==========================================

  /// H1: Display headers, core brand focal points
  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// H2: Screen titles, section identifiers
  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// H3: Card headers, secondary sub-sections
  static const TextStyle h3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    height: 1.4,
  );

  /// Body Large: Primary content blocks, primary body text
  static const TextStyle bodyL = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  /// Body Medium: Secondary descriptive text, standard metadata
  static const TextStyle bodyM = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
  );

  /// Label: Functional elements, microcopy, tags
  static const TextStyle label = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
  );

  // ==========================================
  // LEGACY COMPATIBILITY MAPPINGS
  // Transitioned to Poppins to ensure consistent aesthetics across unmigrated views.
  // ==========================================
  
  static const TextStyle heading1 = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.bold,
    fontSize: 28,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 20,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    color: AppColors.surfaceWhite,
  );
}