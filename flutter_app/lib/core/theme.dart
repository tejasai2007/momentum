import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Habit accent colors users can pick from when creating a habit —
/// mirrors the colorful "pick a color" chip row TickOff uses.
const List<Color> habitColorPalette = [
  Color(0xFF6C5CE7), // violet
  Color(0xFF00B894), // green
  Color(0xFFE17055), // orange
  Color(0xFF0984E3), // blue
  Color(0xFFD63031), // red
  Color(0xFFE84393), // pink
  Color(0xFFFDCB6E), // yellow
  Color(0xFF00CEC9), // teal
];

class AppTheme {
  static ThemeData light = _build(Brightness.light);
  static ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C5CE7),
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF7F7FB),
      textTheme: GoogleFonts.interTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF1C1C1F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1F) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1C1C1F) : Colors.white,
        selectedItemColor: scheme.primary,
        unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
