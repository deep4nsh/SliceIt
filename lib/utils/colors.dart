import 'package:flutter/material.dart';

class AppColors {
  // ==========================================
  // PREMIUM DARK THEME COLOR SYSTEM
  // ==========================================

  // ============ BACKGROUNDS ============
  static const Color darkBackground = Color(0xFF0F0F0F); // App background (near-black)

  // ============ SURFACES ============
  static const Color darkSurface1 = Color(0xFF1A1A1A); // Cards, elevated elements
  static const Color darkSurface2 = Color(0xFF242424); // Slightly more elevated
  static const Color darkSurface3 = Color(0xFF2E2E2E); // Highest elevation

  // ============ SEMANTIC COLORS - PRIMARY (Actions) ============
  static const Color primary = Color(0xFF5B6F82); // Slate blue
  static const Color primaryHover = Color(0xFF6B7F92); // Lighter for hover
  static const Color primaryActive = Color(0xFF4B5F72); // Darker for active
  static const Color primaryDisabled = Color(0xFF4A4A4A); // Muted for disabled

  // ============ SEMANTIC COLORS - SUCCESS (Owed to You) ============
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color successLight = Color(0x1510B981); // 10% opacity for backgrounds
  static const Color successDark = Color(0xFF059669); // Darker for contrast

  // ============ SEMANTIC COLORS - ERROR (You Owe) ============
  static const Color error = Color(0xFFEF4444); // Red
  static const Color errorLight = Color(0x15EF4444); // 10% opacity for backgrounds
  static const Color errorDark = Color(0xFFDC2626); // Darker for contrast

  // ============ SEMANTIC COLORS - WARNING ============
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningLight = Color(0x15F59E0B); // 10% opacity
  static const Color warningDark = Color(0xFFD97706); // Darker for contrast

  // ============ SEMANTIC COLORS - INFO ============
  static const Color info = Color(0xFF0EA5E9); // Sky blue
  static const Color infoLight = Color(0x150EA5E9); // 10% opacity
  static const Color infoDark = Color(0xFF0284C7); // Darker for contrast

  // ============ TEXT COLORS ============
  static const Color textPrimary = Color(0xFFFFFFFF); // Main content
  static const Color textSecondary = Color(0xFFA0A0A0); // Metadata, 60% opacity
  static const Color textTertiary = Color(0xFF757575); // Disabled, hints, 40% opacity

  // ============ BORDER COLORS ============
  static const Color borderDefault = Color(0xFF2E2E2E); // Subtle, one step above bg
  static const Color borderSubtle = Color(0xFF1E1E1E); // Very subtle
  static const Color borderStrong = Color(0xFF3E3E3E); // For emphasis

  // ==========================================
  // LEGACY COMPATIBILITY MAPPINGS
  // These maintain compilation across unmigrated views.
  // ==========================================
  static const Color primaryAccent = primary;
  static const Color secondaryAccent = primary;
  static const Color accentViolet = primary;
  static const Color primaryOrange = primary;
  static const Color secondaryTeal = primary;

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface1 = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF7F8F9);
  static const Color lightSurfaceBorder = Color(0xFFDFDFDF);

  static const Color textLightPrimary = textPrimary;
  static const Color textLightSecondary = textSecondary;
  static const Color textDarkPrimary = textPrimary;
  static const Color textDarkSecondary = textSecondary;

  static const Color darkSurfaceBorder = borderDefault;
  static const Color lightSurfaceWhite = lightSurface1;
  static const Color surfaceWhite = lightSurface1;
  static const Color surfaceDark = darkSurface1;
  static const Color backgroundLight = lightBackground;
  static const Color backgroundDark = darkBackground;
  static const Color textLight = textPrimary;

  static const Color successGreen = success;
  static const Color errorRed = error;
  static const Color warningOrange = warning;

  static const Color primaryNavy = primary;
  static const Color primaryGold = primary;
}
