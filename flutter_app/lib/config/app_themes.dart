import 'package:flutter/material.dart';

/// QuickBite selectable theme identifiers.
enum QuickBiteThemeMode {
  ember,
  saffron,
  midnight;

  String get label {
    switch (this) {
      case QuickBiteThemeMode.ember:
        return 'Ember';
      case QuickBiteThemeMode.saffron:
        return 'Saffron';
      case QuickBiteThemeMode.midnight:
        return 'Midnight';
    }
  }

  String get description {
    switch (this) {
      case QuickBiteThemeMode.ember:
        return 'Warm ivory, forest green, terracotta accents';
      case QuickBiteThemeMode.saffron:
        return 'Bright and friendly, saffron orange accents';
      case QuickBiteThemeMode.midnight:
        return 'Premium dark mode, vibrant orange on charcoal';
    }
  }

  /// Storage key used for persistence.
  static const storageKey = 'quickbite_theme_mode';

  static QuickBiteThemeMode fromStorage(String? value) {
    switch (value) {
      case 'saffron':
        return QuickBiteThemeMode.saffron;
      case 'midnight':
        return QuickBiteThemeMode.midnight;
      case 'ember':
      default:
        return QuickBiteThemeMode.ember;
    }
  }

  String toStorage() => name;
}

/// Resolved color tokens for a single theme.
///
/// Screens and widgets must read colors from here (via
/// `QuickBiteThemes.of(mode)`) instead of hardcoding values, so theme
/// switching is consistent everywhere.
class QuickBiteTokens {
  final QuickBiteThemeMode mode;

  // Brand
  final Color primary;
  final Color primaryDark;
  final Color onPrimary;
  final Color accent;
  final Color accentSoft;

  // Surfaces
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color shadow;

  // Text
  final Color text;
  final Color muted;
  final Color onSurface;

  // Semantic
  final Color success;
  final Color danger;
  final Color warning;

  // Dark flag for conditional tweaks
  final bool isDark;

  const QuickBiteTokens({
    required this.mode,
    required this.primary,
    required this.primaryDark,
    required this.onPrimary,
    required this.accent,
    required this.accentSoft,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.shadow,
    required this.text,
    required this.muted,
    required this.onSurface,
    required this.success,
    required this.danger,
    required this.warning,
    required this.isDark,
  });
}

/// Theme definitions: Ember, Saffron, Midnight.
class QuickBiteThemes {
  QuickBiteThemes._();

  static const ember = QuickBiteTokens(
    mode: QuickBiteThemeMode.ember,
    // Deep forest green primary, terracotta CTA
    primary: Color(0xFF1B4332),
    primaryDark: Color(0xFF143326),
    onPrimary: Color(0xFFFFFBF3),
    accent: Color(0xFFE07A3F),
    accentSoft: Color(0xFFFBE9D9),
    // Warm ivory surfaces
    background: Color(0xFFFAF6EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3ECDD),
    border: Color(0xFFE7DCC6),
    shadow: Color(0xFF3B2A1A),
    // Text
    text: Color(0xFF22301F),
    muted: Color(0xFF7A7263),
    onSurface: Color(0xFF22301F),
    // Semantic
    success: Color(0xFF2D6A4F),
    danger: Color(0xFFC0392B),
    warning: Color(0xFFD97706),
    isDark: false,
  );

  static const saffron = QuickBiteTokens(
    mode: QuickBiteThemeMode.saffron,
    // Saffron orange primary
    primary: Color(0xFFF97316),
    primaryDark: Color(0xFFEA580C),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF16A34A),
    accentSoft: Color(0xFFE8F7EE),
    // Light clean surfaces
    background: Color(0xFFFFFBF5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFDF3E7),
    border: Color(0xFFF0E2CC),
    shadow: Color(0xFF7A4A1A),
    // Text
    text: Color(0xFF292018),
    muted: Color(0xFF8A7A63),
    onSurface: Color(0xFF292018),
    // Semantic
    success: Color(0xFF16A34A),
    danger: Color(0xFFDC2626),
    warning: Color(0xFFD97706),
    isDark: false,
  );

  static const midnight = QuickBiteTokens(
    mode: QuickBiteThemeMode.midnight,
    // Vibrant orange on charcoal
    primary: Color(0xFFFF8C42),
    primaryDark: Color(0xFFE56B23),
    onPrimary: Color(0xFF1A120B),
    accent: Color(0xFF4ADE80),
    accentSoft: Color(0xFF1E2E24),
    // Dark charcoal surfaces
    background: Color(0xFF121110),
    surface: Color(0xFF1C1B1A),
    surfaceAlt: Color(0xFF262524),
    border: Color(0xFF35322E),
    shadow: Color(0xFF000000),
    // Text
    text: Color(0xFFF5EFE6),
    muted: Color(0xFFA39E93),
    onSurface: Color(0xFFF5EFE6),
    // Semantic
    success: Color(0xFF4ADE80),
    danger: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    isDark: true,
  );

  static QuickBiteTokens of(QuickBiteThemeMode mode) {
    switch (mode) {
      case QuickBiteThemeMode.ember:
        return ember;
      case QuickBiteThemeMode.saffron:
        return saffron;
      case QuickBiteThemeMode.midnight:
        return midnight;
    }
  }

  /// Builds a Material [ThemeData] from tokens.
  static ThemeData themeData(QuickBiteTokens t) {
    final brightness = t.isDark ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      secondary: t.accent,
      onSecondary: t.onPrimary,
      surface: t.surface,
      onSurface: t.onSurface,
      error: t.danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: t.primary,
      scaffoldBackgroundColor: t.background,
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: t.text,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.danger),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: t.muted, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: t.border),
        ),
        labelStyle: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: t.text),
      ),
      dividerColor: t.border,
      textTheme: TextTheme(
        displayLarge: TextStyle(
            fontSize: 34, fontWeight: FontWeight.w800, color: t.text,
            letterSpacing: -0.8, height: 1.15),
        displayMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w800, color: t.text,
            letterSpacing: -0.6, height: 1.2),
        headlineSmall: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: t.text,
            letterSpacing: -0.3),
        titleLarge: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700, color: t.text,
            letterSpacing: -0.2),
        titleMedium: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: t.text),
        bodyLarge: TextStyle(fontSize: 16, color: t.text, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, color: t.text, height: 1.45),
        bodySmall: TextStyle(fontSize: 12.5, color: t.muted, height: 1.4),
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: t.text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.accentSoft,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.text),
        ),
      ),
    );
  }
}
