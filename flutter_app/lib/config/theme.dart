import 'package:flutter/material.dart';

/// QuickBite premium design system.
///
/// Food-inspired palette: deep tomato primary, warm amber accent, creamy
/// neutrals. All colors, radii, spacing and shadows flow from here — screens
/// must use these tokens instead of hardcoding values.
class AppTheme {
  // Brand
  static const Color primary = Color(0xFFE5484D); // Tomato red
  static const Color primaryDark = Color(0xFFC93338);
  static const Color secondary = Color(0xFFF59E0B); // Warm amber
  static const Color accent = Color(0xFF7C3AED); // Deep violet (rare highlights)

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF2563EB);

  // Light theme surfaces
  static const Color lightBg = Color(0xFFFAF7F2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF3EDE3);
  static const Color lightText = Color(0xFF221C15);
  static const Color lightMuted = Color(0xFF8A7E6E);
  static const Color lightBorder = Color(0xFFE9DFD0);

  // Dark theme surfaces
  static const Color darkBg = Color(0xFF14100C);
  static const Color darkSurface = Color(0xFF1F1913);
  static const Color darkSurfaceAlt = Color(0xFF2A221A);
  static const Color darkText = Color(0xFFF6F0E6);
  static const Color darkMuted = Color(0xFFA89A86);
  static const Color darkBorder = Color(0xFF3A2F24);

  // Geometry
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 28;

  // Spacing scale
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  static List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.35)
            : const Color(0xFF3B2A1A).withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static LinearGradient brandGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE5484D), Color(0xFFD63A5C)],
  );

  static LinearGradient warmGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFE5484D)],
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: lightSurface,
        error: danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: lightText,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: danger),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: lightMuted, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
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
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      dividerColor: lightBorder,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 34, fontWeight: FontWeight.w800, color: lightText,
            letterSpacing: -0.8, height: 1.15),
        displayMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w800, color: lightText,
            letterSpacing: -0.6, height: 1.2),
        headlineSmall: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: lightText,
            letterSpacing: -0.3),
        titleLarge: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700, color: lightText,
            letterSpacing: -0.2),
        titleMedium: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: lightText),
        bodyLarge: TextStyle(fontSize: 16, color: lightText, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, color: lightText, height: 1.45),
        bodySmall: TextStyle(fontSize: 12.5, color: lightMuted, height: 1.4),
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: lightText),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: darkSurface,
        error: danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkText,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: danger),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: darkMuted, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
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
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      dividerColor: darkBorder,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 34, fontWeight: FontWeight.w800, color: darkText,
            letterSpacing: -0.8, height: 1.15),
        displayMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w800, color: darkText,
            letterSpacing: -0.6, height: 1.2),
        headlineSmall: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: darkText,
            letterSpacing: -0.3),
        titleLarge: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700, color: darkText,
            letterSpacing: -0.2),
        titleMedium: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: darkText),
        bodyLarge: TextStyle(fontSize: 16, color: darkText, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, color: darkText, height: 1.45),
        bodySmall: TextStyle(fontSize: 12.5, color: darkMuted, height: 1.4),
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: darkText),
      ),
    );
  }
}
