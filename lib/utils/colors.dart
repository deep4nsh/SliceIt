import 'package:flutter/material.dart';

class AppColors {
  // ==========================================
  // SLATE & EMERALD PREMIUM COLOR SYSTEM
  // Enterprise-grade fintech aesthetic
  // ==========================================

  // ============ BACKGROUNDS ============
  static const Color darkBackground = Color(0xFF0D1117); // Char-black, absolute
  static const Color darkBackgroundSecondary = Color(0xFF161B22); // Slightly elevated

  // ============ SURFACES ============
  static const Color darkSurface1 = Color(0xFF21262D); // Interactive elements
  static const Color darkSurface2 = Color(0xFF30363D); // Floating/elevated
  static const Color darkSurface3 = Color(0xFF30363D); // Highest elevation (same as 2)

  // ============ SEMANTIC COLORS - PRIMARY (Actions) ============
  static const Color primary = Color(0xFF58A6FF); // Core action blue
  static const Color primaryHover = Color(0xFF79C0FF); // Lightened for interaction
  static const Color primaryActive = Color(0xFF1F6FEB); // Darkened for pressed
  static const Color primaryDisabled = Color(0xFF6E7681); // Inactive elements

  // ============ SEMANTIC COLORS - SUCCESS (Owed to You) ============
  static const Color success = Color(0xFF3FB950); // Confirmation emerald
  static const Color successLight = Color(0x153FB950); // 10% opacity for backgrounds
  static const Color successDark = Color(0xFF238636); // Darker for contrast

  // ============ SEMANTIC COLORS - ERROR (You Owe) ============
  static const Color error = Color(0xFFF85149); // Fintech red
  static const Color errorLight = Color(0x15F85149); // 10% opacity for backgrounds
  static const Color errorDark = Color(0xFFDA3633); // Darker for contrast

  // ============ SEMANTIC COLORS - WARNING ============
  static const Color warning = Color(0xFFD29922); // Amber for caution
  static const Color warningLight = Color(0x15D29922); // 10% opacity
  static const Color warningDark = Color(0xFFBF8700); // Darker for contrast

  // ============ SEMANTIC COLORS - SECONDARY ============
  static const Color secondary = Color(0xFF1F6FEB); // Related actions
  static const Color secondaryLight = Color(0x151F6FEB); // 10% opacity
  static const Color secondaryDark = Color(0xFF0969DA); // Darker variant

  // ============ SEMANTIC COLORS - INFO (Member actions, notifications) ============
  static const Color info = Color(0xFF06B6D4); // Teal for info states
  static const Color infoLight = Color(0x1506B6D4); // 10% opacity
  static const Color infoDark = Color(0xFF0891B2); // Darker for contrast

  // ============ TEXT COLORS - DARK MODE ============
  static const Color textPrimary = Color(0xFFFFFFFF); // Main content in dark mode
  static const Color textSecondary = Color(0xFFC9D1D9); // Labels, placeholders in dark mode
  static const Color textTertiary = Color(0xFF8B949E); // Disabled, hints in dark mode

  // ============ TEXT COLORS - LIGHT MODE ============
  static const Color textDarkModePrimary = Color(0xFF1F2937); // Main content in light mode
  static const Color textDarkModeSecondary = Color(0xFF6B7280); // Labels in light mode
  static const Color textDarkModeTertiary = Color(0xFF9CA3AF); // Disabled in light mode

  // ============ BORDER COLORS ============
  static const Color borderDefault = Color(0xFF30363D); // All dividers and edges
  static const Color borderSubtle = Color(0xFF21262D); // Very subtle separations
  static const Color borderStrong = Color(0xFF30363D); // For emphasis

  // ============ DATA VISUALIZATION COLORS ============
  static const Color chartPositive = Color(0xFF56D364); // Revenue, money in
  static const Color chartNegative = Color(0xFFFF7B72); // Spending, money out
  static const Color settlementComplete = Color(0xFF3FB950); // Settlement completion
  static const Color settlementPending = Color(0xFFDAA81A); // Awaiting settlement

  // ============ MEMBER COLORS (for multi-person identification) ============
  static const Color memberColor1 = Color(0xFF58A6FF); // Blue
  static const Color memberColor2 = Color(0xFF3FB950); // Emerald
  static const Color memberColor3 = Color(0xFFD29922); // Amber
  static const Color memberColor4 = Color(0xFFF85149); // Red
  static const Color memberColor5 = Color(0xFF06B6D4); // Teal

  // ============ INTERACTION STATES ============
  static const Color focusRing = Color(0xFF58A6FF); // 2px outline for a11y
  static const Color hoverOverlay = Color(0xFFFFFFFF); // opacity 8% for hover

  // ==========================================
  // LEGACY COMPATIBILITY MAPPINGS
  // These maintain compilation across unmigrated views.
  // ==========================================
  static const Color primaryAccent = primary;
  static const Color secondaryAccent = secondary;
  static const Color accentViolet = secondary;
  static const Color primaryOrange = warning;
  static const Color secondaryTeal = Color(0xFF06B6D4);

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface1 = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF7F8F9);
  static const Color lightSurfaceBorder = Color(0xFFDFDFDF);

  static const Color textLightPrimary = textPrimary; // White text for dark mode
  static const Color textLightSecondary = textSecondary; // Light gray for dark mode
  static const Color textDarkPrimary = textDarkModePrimary; // Dark text for light mode
  static const Color textDarkSecondary = textDarkModeSecondary; // Gray text for light mode

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
  static const Color primaryGold = warning;
}
