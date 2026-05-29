import 'package:flutter/material.dart';

class AppColors {
  // ==========================================
  // PREMIUM MINIMALIST DESIGN SYSTEM TOKENS
  // ==========================================

  // Brand Accents - Subtle & Refined
  static const primaryAccent = Color(0xFF5B6F82); // Muted Slate Blue (Premium)
  static const secondaryAccent = Color(0xFF6B9EAA); // Soft Teal (Subtle)
  static const accentViolet = Color(0xFF7A8B9E); // Neutral Slate (Refined)

  // Dark Mode Palette
  static const darkBackground = Color(0xFF1A1A1A); // Deep Charcoal
  static const darkSurface1 = Color(0xFF2A2A2A); // Subtle Dark Gray
  static const darkSurface2 = Color(0xFF3A3A3A); // Lighter Dark Gray
  static const darkSurfaceBorder = Color(0xFF4A4A4A); // Soft Border

  // Light Mode Palette - Premium White
  static const lightBackground = Color(0xFFFFFFFF); // Pure White
  static const lightSurface1 = Color(0xFFFFFFFF); // White Cards
  static const lightSurface2 = Color(0xFFF7F8F9); // Subtle Light Gray
  static const lightSurfaceBorder = Color(0xFFDFDFDF); // Refined Border

  // Unified Text Colors
  static const textLightPrimary = Color(0xFFFFFFFF);
  static const textLightSecondary = Color(0xFFA0A0A0); // Soft Gray
  static const textDarkPrimary = Color(0xFF1A1A1A); // Dark Charcoal
  static const textDarkSecondary = Color(0xFF757575); // Muted Gray

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
