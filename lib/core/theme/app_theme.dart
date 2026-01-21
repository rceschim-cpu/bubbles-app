import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData dark() {
    const bg = Color(0xFF0B0F14);
    const surface = Color(0xFF0F1620);
    const text = Color(0xFFEAF0F7);
    const muted = Color(0xFF9AA7B6);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: Color(0xFF6EA8FE),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.25,
          color: text,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.25,
          color: muted,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface.withOpacity(0.9),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerColor: Colors.white.withOpacity(0.08),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
