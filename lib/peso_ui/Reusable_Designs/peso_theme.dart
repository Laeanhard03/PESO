import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Cached, native Material styling: no font downloads or animation packages.
abstract final class PesoTheme {
  static final ThemeData light = _build();

  static ThemeData _build() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: PesoTokens.brandGreen,
          brightness: Brightness.light,
        ).copyWith(
          primary: PesoTokens.brandGreen,
          onPrimary: Colors.white,
          secondary: const Color(0xFF946B24),
          tertiary: PesoTokens.infoBlue,
          surface: Colors.white,
          onSurface: PesoTokens.textPrimary,
          onSurfaceVariant: PesoTokens.textSecondary,
          outline: const Color(0xFF7B8D86),
          outlineVariant: const Color(0xFFDCE5E0),
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PesoTokens.radiusInput),
    );
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFDCE5E0)),
    );
    return base.copyWith(
      scaffoldBackgroundColor: PesoTokens.surfaceNeutral,
      dividerColor: const Color(0xFFDCE5E0),
      textTheme: base.textTheme.copyWith(
        headlineLarge: PesoTokens.headlineLarge,
        headlineMedium: PesoTokens.headlineMedium,
        headlineSmall: PesoTokens.headlineSmall,
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: PesoTokens.textPrimary,
        ),
        bodyLarge: PesoTokens.bodyMedium,
        bodyMedium: PesoTokens.bodySmall.copyWith(
          color: PesoTokens.textPrimary,
        ),
        bodySmall: PesoTokens.bodySmall.copyWith(fontSize: 12),
        labelLarge: PesoTokens.labelLarge,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: PesoTokens.brandGreenLight,
        side: const BorderSide(color: Color(0xFFD6E5DB)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: PesoTokens.labelLarge,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFE1F0E6),
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: PesoTokens.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDCE5E0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAF9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: PesoTokens.brandGreen, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: PesoTokens.errorRed),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: PesoTokens.errorRed, width: 2),
        ),
        hintStyle: const TextStyle(color: PesoTokens.textMuted, fontSize: 14),
        floatingLabelStyle: const TextStyle(
          color: PesoTokens.brandGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: PesoTokens.labelLarge,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PesoTokens.brandGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: PesoTokens.labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
          side: const BorderSide(color: Color(0xFFC8D6CE)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: PesoTokens.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
          textStyle: PesoTokens.labelLarge,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFDCE5E0),
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: shape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        contentTextStyle: const TextStyle(
          color: PesoTokens.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE0E9E4)),
        ),
        showCloseIcon: true,
        closeIconColor: PesoTokens.textSecondary,
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PesoTokens.brandGreen,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(Color(0xFFF0F5F2)),
        headingTextStyle: PesoTokens.labelLarge,
        dataTextStyle: PesoTokens.bodySmall.copyWith(
          color: PesoTokens.textPrimary,
        ),
        dividerThickness: 0.5,
      ),
    );
  }
}
