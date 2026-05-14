import 'package:flutter/material.dart';

class AppColors {
  // ==========================================
  // PROFESSIONAL FINANCE DESIGN SYSTEM TOKENS
  // ==========================================
  
  // Brand Accents
  static const primaryAccent = Color(0xFF1E3A8A); // Deep Navy
  static const secondaryAccent = Color(0xFF0EA5E9); // Calm Cerulean
  static const accentViolet = Color(0xFF334155); // Slate Gray (neutralized)

  // Dark Mode Palette
  static const darkBackground = Color(0xFF0F172A); // Slate 900
  static const darkSurface1 = Color(0xFF1E293B); // Slate 800
  static const darkSurface2 = Color(0xFF334155); // Slate 700
  static const darkSurfaceBorder = Color(0xFF475569); // Slate 600

  // Light Mode Palette
  static const lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const lightSurface1 = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFF1F5F9); // Slate 100
  static const lightSurfaceBorder = Color(0xFFE2E8F0); // Slate 200

  // Unified Text Colors
  static const textLightPrimary = Color(0xFFFFFFFF);
  static const textLightSecondary = Color(0xFF94A3B8); // Slate 400
  static const textDarkPrimary = Color(0xFF0F172A); // Slate 900
  static const textDarkSecondary = Color(0xFF64748B); // Slate 500

  // Semantic / Functional
  static const success = Color(0xFF10B981); // Emerald
  static const error = Color(0xFFEF4444); // Red
  static const warning = Color(0xFFF59E0B); // Amber

  // ==========================================
  // LEGACY COMPATIBILITY MAPPINGS
  // Preserved to maintain seamless compilation across all unmigrated views.
  // Mapped to harmonious equivalents within the new design language.
  // ==========================================
  static const primaryOrange = primaryAccent; 
  static const primaryPeach = secondaryAccent;
  static const secondaryTeal = secondaryAccent;

  static const backgroundLight = lightBackground;
  static const surfaceWhite = lightSurface1;
  static const backgroundDark = darkBackground;
  static const surfaceDark = darkSurface1;
  
  static const textPrimary = textLightPrimary; // Defaulting dark-first text primary
  static const textSecondary = textLightSecondary;
  static const textLight = textLightPrimary;

  static const successGreen = success;
  static const errorRed = error;
  static const warningOrange = warning;

  static const primaryNavy = primaryAccent; 
  static const primaryGold = secondaryAccent;
}
