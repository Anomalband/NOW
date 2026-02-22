import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

class NowTheme {
  const NowTheme._();

  static ThemeData light() {
    const brandBlue = Color(0xFF0F5E78);
    const brandOrange = Color(0xFFF06A3B);

    final textTheme = GoogleFonts.manropeTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandBlue,
        primary: brandBlue,
        secondary: brandOrange,
        brightness: Brightness.light,
      ),
      textTheme: textTheme.copyWith(
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      ),
      scaffoldBackgroundColor: const Color(0xFFF2F6F8),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.85),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE3EEF2),
        side: BorderSide.none,
        labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      ),
    );
  }
}
