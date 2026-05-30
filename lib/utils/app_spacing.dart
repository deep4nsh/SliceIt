class AppSpacing {
  // ==========================================
  // 8PT GRID BASE UNIT
  // ==========================================
  static const double unit = 8.0;

  // ==========================================
  // SPACING SCALE (8pt multiples)
  // ==========================================
  static const double xs = 4.0; // 0.5 units (rare)
  static const double sm = 8.0; // 1 unit
  static const double md = 12.0; // 1.5 units
  static const double base = 16.0; // 2 units (standard)
  static const double lg = 24.0; // 3 units
  static const double xl = 32.0; // 4 units
  static const double xxl = 48.0; // 6 units
  static const double xxxl = 64.0; // 8 units

  // ==========================================
  // COMPONENT SIZING
  // ==========================================
  static const double touchTarget = 44.0; // Min touch target size
  static const double iconSize = 24.0;
  static const double avatarSize = 40.0;

  // ==========================================
  // COMPONENT PADDING
  // ==========================================
  static const double buttonPaddingV = 12.0; // Vertical
  static const double buttonPaddingH = 16.0; // Horizontal
  static const double cardPadding = 16.0; // Standard card padding
  static const double cardPaddingLarge = 20.0; // Large card padding
  static const double inputPadding = 12.0; // Input field padding

  // ==========================================
  // SCREEN PADDING
  // ==========================================
  static const double screenPadding = 16.0; // Horizontal screen margins
  static const double safeAreaTop = 16.0; // Top padding after safe area
  static const double safeAreaBottom = 100.0; // Bottom padding for nav bar + buffer

  // ==========================================
  // GAPS (spacing between elements)
  // ==========================================
  static const double gapXs = 4.0;
  static const double gapSm = 8.0;
  static const double gapBase = 12.0;
  static const double gapMd = 16.0;
  static const double gapLg = 24.0;
  static const double gapXl = 32.0;
  static const double gapSection = 48.0; // Between major sections

  // ==========================================
  // BORDER RADIUS (rounded corners)
  // ==========================================
  static const double radiusSm = 8.0; // Small buttons, inputs
  static const double radiusMd = 12.0; // Cards, standard components
  static const double radiusLg = 16.0; // Large components, modals
  static const double radiusPill = 24.0; // Pill-shaped elements

  // Legacy aliases for compatibility
  static const double radiusButton = radiusSm;
  static const double radiusCard = radiusMd;
}
