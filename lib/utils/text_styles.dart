import 'package:flutter/material.dart';

class AppTextStyles {
  static const String _fontFamily = 'Inter';

  // ==========================================
  // PREMIUM TYPOGRAPHY SCALE (Inter)
  // ==========================================

  /// Display: Brand focal points, rare use (40px)
  static const TextStyle display = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01,
    height: 1.1,
  );

  /// H1: Page titles, major headers (32px)
  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01,
    height: 1.2,
  );

  /// H2: Section headers (24px)
  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  /// H3: Card titles, subsections (18px)
  static const TextStyle h3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  /// Subtitle: Above card titles (12px, weight 500)
  static const TextStyle subtitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.04,
    height: 1.2,
  );

  /// Body Large: Primary content (16px)
  static const TextStyle bodyL = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  /// Body: Standard body text (14px)
  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  /// Body Medium: Alias for body
  static const TextStyle bodyM = body;

  /// Caption: Metadata, timestamps (12px)
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
  );

  /// Label: Button text, tags, UI labels (13px, weight 500)
  static const TextStyle label = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.03,
    height: 1.2,
  );

  /// Helper: Hints, instructions (12px)
  static const TextStyle helper = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
  );

  // ==========================================
  // LEGACY COMPATIBILITY MAPPINGS
  // ==========================================
  static const TextStyle heading1 = h1;
  static const TextStyle heading2 = h2;
  static const TextStyle button = label;
}