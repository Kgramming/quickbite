import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFE5484D); // Tomato red
  static const Color secondary = Color(0xFFF59E0B); // Orange
  static const Color success = Color(0xFF16A34A); // Green
  static const Color danger = Color(0xFFDC2626); // Red
  static const Color warning = Color(0xFFD97706); // Amber
  static const Color info = Color(0xFF2563EB); // Blue

  // Light theme colors
  static const Color lightBg = Color(0xFFFAF6F0);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF23201C);
  static const Color lightMuted = Color(0xFF8A8177);
  static const Color lightBorder = Color(0xFFEADFD2);

  // Dark theme colors
  static const Color darkBg = Color(0xFF191410);
  static const Color darkSurface = Color(0xFF241D16);
  static const Color darkText = Color(0xFFF5EFE4);
  static const Color darkMuted = Color(0xFFAB9E8D);
  static const Color darkBorder = Color(0xFF3E332A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightText,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: lightText),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: lightText),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: lightText),
        bodyLarge: TextStyle(fontSize: 16, color: lightText),
        bodyMedium: TextStyle(fontSize: 14, color: lightText),
        bodySmall: TextStyle(fontSize: 12, color: lightMuted),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF2A221A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: darkText),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkText),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: darkText),
        bodyLarge: TextStyle(fontSize: 16, color: darkText),
        bodyMedium: TextStyle(fontSize: 14, color: darkText),
        bodySmall: TextStyle(fontSize: 12, color: darkMuted),
      ),
    );
  }
}
