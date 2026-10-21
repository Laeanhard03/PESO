import 'package:flutter/material.dart';

/// PESO JobKonek Design Tokens — single source of truth for the visual system.
/// Based on the ChatGPT design spec (2026-10-19).
/// All members are static constants — use PesoTokens directly.
class PesoTokens {
  // Private constructor to prevent instantiation.
  const PesoTokens._();

  // ============================================================
  // COLOR PALETTE
  // ============================================================

  /// Primary brand green — DOLE/PESO official green.
  static const Color brandGreen = Color(0xFF236349);

  /// Darker green for active states and emphasis.
  static const Color brandGreenDark = Color(0xFF174B37);

  /// Lighter green for backgrounds and hover states.
  static const Color brandGreenLight = Color(0xFFE7F1EB);

  /// Very light green for subtle accents.
  static const Color brandGreenPale = Color(0xFFF0F6F2);

  /// Neutral text colors.
  static const Color textPrimary = Color(0xFF17352B);
  static const Color textSecondary = Color(0xFF52675D);
  static const Color textMuted = Color(0xFF667B70);
  static const Color textOnGreen = Colors.white;

  /// Surface colors.
  static const Color surfaceWhite = Colors.white;
  static const Color surfaceNeutral = Color(0xFFF5F7F5);
  static const Color surfaceDark = Color(0xFF17352B);

  /// Status colors.
  static const Color successGreen = Color(0xFF236349);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color infoBlue = Color(0xFF2563EB);

  // ============================================================
  // SPACING TOKENS (dp)
  // ============================================================

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space16 = 64;
  static const double space20 = 80;
  static const double space24 = 96;

  /// Semantic spacing aliases.
  static const double spacingXS = space1;   // 4
  static const double spacingSM = space2;   // 8
  static const double spacingMD = space4;   // 16
  static const double spacingLG = space6;   // 24
  static const double spacingXL = space8;   // 32
  static const double spacing2XL = space10; // 40
  static const double spacing3XL = space12; // 48
  static const double spacing4XL = space16; // 64

  // ============================================================
  // BORDER RADIUS TOKENS (dp)
  // ============================================================

  static const double radiusSM = 8;
  static const double radiusMD = 12;
  static const double radiusLG = 16;
  static const double radiusXL = 20;
  static const double radius2XL = 28;
  static const double radiusFull = 9999;

  /// Semantic radius aliases.
  static const double radiusCard = radiusLG;      // 16
  static const double radiusButton = radiusMD;  // pill
  static const double radiusInput = radiusMD;     // 12
  static const double radiusContainer = radiusXL; // 20

  // ============================================================
  // SHADOW TOKENS
  // ============================================================

  /// Subtle shadow for cards and containers.
  static const List<BoxShadow> shadowSM = [
    BoxShadow(
      color: Color(0x141A1A2E), // 8% black
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Medium shadow for elevated cards and modals.
  static const List<BoxShadow> shadowMD = [
    BoxShadow(
      color: Color(0x1F1A1A2E), // 12% black
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Strong shadow for dropdowns, dialogs, floating elements.
  static const List<BoxShadow> shadowLG = [
    BoxShadow(
      color: Color(0x261A1A2E), // 15% black
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Navigation bar shadow (scrolled state).
  static const List<BoxShadow> shadowNav = [
    BoxShadow(
      color: Color(0x10000000), // 20% black
      blurRadius: 8,
      offset: Offset(0, 0),
    ),
  ];

  // ============================================================
  // TYPOGRAPHY SCALE
  // ============================================================

  /// Display / Hero headlines.
  static const TextStyle displayLarge = TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w900,
    height: 1.05,
    letterSpacing: -1.5,
    color: textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    height: 1.1,
    letterSpacing: -1,
    color: textPrimary,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
    color: textPrimary,
  );

  /// Section headlines.
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.2,
    color: textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: textPrimary,
  );

  /// Body text.
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: textSecondary,
  );

  /// Label / UI text.
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
    color: textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.2,
    color: textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.3,
    color: textMuted,
  );

  /// Navigation / button text.
  static const TextStyle navLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: textSecondary,
  );

  static const TextStyle navLabelActive = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: brandGreenDark,
  );

  static const TextStyle buttonLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: textOnGreen,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: textOnGreen,
  );

  // ============================================================
  // MOTION TOKENS
  // ============================================================

  static const Duration durationFast = Duration(milliseconds: 120);
  static const Duration durationNormal = Duration(milliseconds: 180);
  static const Duration durationMedium = Duration(milliseconds: 220);
  static const Duration durationSlow = Duration(milliseconds: 320);
  static const Duration durationSlowest = Duration(milliseconds: 400);

  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveEmphasized = Curves.easeOutCubic;
  static const Curve curveDecelerate = Curves.decelerate;

  /// Entrance animation for hero logo.
  static const Duration logoEntranceDuration = Duration(milliseconds: 320);
  static const Curve logoEntranceCurve = Curves.easeOutCubic;
  static const double logoEntranceInitialScale = 0.94;

  /// Navigation active state transition.
  static const Duration navTransitionDuration = Duration(milliseconds: 220);
  static const Curve navTransitionCurve = Curves.easeOutCubic;

  /// Card hover/tap transition.
  static const Duration cardTransitionDuration = Duration(milliseconds: 180);
  static const Curve cardTransitionCurve = Curves.easeOutCubic;

  // ============================================================
  // LAYOUT CONSTRAINTS
  // ============================================================

  /// Maximum content width for desktop layouts.
  static const double maxContentWidth = 1200;

  /// Breakpoints.
  static const double breakpointCompact = 600;
  static const double breakpointTablet = 1024;
  static const double breakpointDesktop = 1280;

  /// Header heights.
  static const double headerHeightDesktop = 76;
  static const double headerHeightCompact = 64;

  /// Bottom navigation bar height.
  static const double bottomNavHeight = 76;

  /// Hero minimum height.
  static const double heroMinHeightDesktop = 720;
  static const double heroMinHeightCompact = 560;

  /// Logo sizes.
  static const double logoSizeLarge = 72;     // Hero / desktop header
  static const double logoSizeMedium = 56;    // Desktop header / footer
  static const double logoSizeSmall = 48;     // Mobile header / cards
  static const double logoSizeHero = 88;      // Prominent hero icon

  // ============================================================
  // HELPER METHODS
  // ============================================================

  static EdgeInsets horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < breakpointCompact) return const EdgeInsets.symmetric(horizontal: space4);
    if (width < breakpointDesktop) return const EdgeInsets.symmetric(horizontal: space6);
    return const EdgeInsets.symmetric(horizontal: space10);
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < breakpointCompact) return const EdgeInsets.all(space4);
    if (width < breakpointDesktop) return const EdgeInsets.symmetric(horizontal: space6, vertical: space8);
    return const EdgeInsets.symmetric(horizontal: space10, vertical: space10);
  }
}
/// Immutable instance facade used by reusable widgets; constants live in PesoTokens.
class PesoDesignTokens {
  const PesoDesignTokens();

  final Color brandGreen = PesoTokens.brandGreen;
  final Color brandGreenDark = PesoTokens.brandGreenDark;
  final Color brandGreenLight = PesoTokens.brandGreenLight;
  final Color brandGreenPale = PesoTokens.brandGreenPale;
  final Color textPrimary = PesoTokens.textPrimary;
  final Color textSecondary = PesoTokens.textSecondary;
  final Color textMuted = PesoTokens.textMuted;
  final Color textOnGreen = PesoTokens.textOnGreen;
  final Color surfaceWhite = PesoTokens.surfaceWhite;
  final Color surfaceNeutral = PesoTokens.surfaceNeutral;
  final Color surfaceDark = PesoTokens.surfaceDark;
  final Color successGreen = PesoTokens.successGreen;
  final Color warningAmber = PesoTokens.warningAmber;
  final Color errorRed = PesoTokens.errorRed;
  final Color infoBlue = PesoTokens.infoBlue;

  final double space1 = PesoTokens.space1;
  final double space2 = PesoTokens.space2;
  final double space3 = PesoTokens.space3;
  final double space4 = PesoTokens.space4;
  final double space5 = PesoTokens.space5;
  final double space6 = PesoTokens.space6;
  final double space8 = PesoTokens.space8;
  final double space10 = PesoTokens.space10;
  final double space12 = PesoTokens.space12;
  final double space16 = PesoTokens.space16;
  final double space20 = PesoTokens.space20;
  final double space24 = PesoTokens.space24;
  final double spacingXS = PesoTokens.spacingXS;
  final double spacingSM = PesoTokens.spacingSM;
  final double spacingMD = PesoTokens.spacingMD;
  final double spacingLG = PesoTokens.spacingLG;
  final double spacingXL = PesoTokens.spacingXL;
  final double spacing2XL = PesoTokens.spacing2XL;
  final double spacing3XL = PesoTokens.spacing3XL;
  final double spacing4XL = PesoTokens.spacing4XL;

  final double radiusSM = PesoTokens.radiusSM;
  final double radiusMD = PesoTokens.radiusMD;
  final double radiusLG = PesoTokens.radiusLG;
  final double radiusXL = PesoTokens.radiusXL;
  final double radius2XL = PesoTokens.radius2XL;
  final double radiusFull = PesoTokens.radiusFull;
  final double radiusCard = PesoTokens.radiusCard;
  final double radiusButton = PesoTokens.radiusButton;
  final double radiusInput = PesoTokens.radiusInput;
  final double radiusContainer = PesoTokens.radiusContainer;

  final List<BoxShadow> shadowSM = PesoTokens.shadowSM;
  final List<BoxShadow> shadowMD = PesoTokens.shadowMD;
  final List<BoxShadow> shadowLG = PesoTokens.shadowLG;
  final List<BoxShadow> shadowNav = PesoTokens.shadowNav;

  final TextStyle displayLarge = PesoTokens.displayLarge;
  final TextStyle displayMedium = PesoTokens.displayMedium;
  final TextStyle displaySmall = PesoTokens.displaySmall;
  final TextStyle headlineLarge = PesoTokens.headlineLarge;
  final TextStyle headlineMedium = PesoTokens.headlineMedium;
  final TextStyle headlineSmall = PesoTokens.headlineSmall;
  final TextStyle bodyLarge = PesoTokens.bodyLarge;
  final TextStyle bodyMedium = PesoTokens.bodyMedium;
  final TextStyle bodySmall = PesoTokens.bodySmall;
  final TextStyle labelLarge = PesoTokens.labelLarge;
  final TextStyle labelMedium = PesoTokens.labelMedium;
  final TextStyle labelSmall = PesoTokens.labelSmall;
  final TextStyle navLabel = PesoTokens.navLabel;
  final TextStyle navLabelActive = PesoTokens.navLabelActive;
  final TextStyle buttonLarge = PesoTokens.buttonLarge;
  final TextStyle buttonMedium = PesoTokens.buttonMedium;

  final Duration durationFast = PesoTokens.durationFast;
  final Duration durationNormal = PesoTokens.durationNormal;
  final Duration durationMedium = PesoTokens.durationMedium;
  final Duration durationSlow = PesoTokens.durationSlow;
  final Duration durationSlowest = PesoTokens.durationSlowest;
  final Curve curveStandard = PesoTokens.curveStandard;
  final Curve curveEmphasized = PesoTokens.curveEmphasized;
  final Curve curveDecelerate = PesoTokens.curveDecelerate;
  final Duration logoEntranceDuration = PesoTokens.logoEntranceDuration;
  final Curve logoEntranceCurve = PesoTokens.logoEntranceCurve;
  final double logoEntranceInitialScale = PesoTokens.logoEntranceInitialScale;
  final Duration navTransitionDuration = PesoTokens.navTransitionDuration;
  final Curve navTransitionCurve = PesoTokens.navTransitionCurve;
  final Duration cardTransitionDuration = PesoTokens.cardTransitionDuration;
  final Curve cardTransitionCurve = PesoTokens.cardTransitionCurve;

  final double maxContentWidth = PesoTokens.maxContentWidth;
  final double breakpointCompact = PesoTokens.breakpointCompact;
  final double breakpointTablet = PesoTokens.breakpointTablet;
  final double breakpointDesktop = PesoTokens.breakpointDesktop;
  final double headerHeightDesktop = PesoTokens.headerHeightDesktop;
  final double headerHeightCompact = PesoTokens.headerHeightCompact;
  final double bottomNavHeight = PesoTokens.bottomNavHeight;
  final double heroMinHeightDesktop = PesoTokens.heroMinHeightDesktop;
  final double heroMinHeightCompact = PesoTokens.heroMinHeightCompact;
  final double logoSizeLarge = PesoTokens.logoSizeLarge;
  final double logoSizeMedium = PesoTokens.logoSizeMedium;
  final double logoSizeSmall = PesoTokens.logoSizeSmall;
  final double logoSizeHero = PesoTokens.logoSizeHero;

  EdgeInsets horizontalPadding(BuildContext context) => PesoTokens.horizontalPadding(context);
  EdgeInsets pagePadding(BuildContext context) => PesoTokens.pagePadding(context);
}