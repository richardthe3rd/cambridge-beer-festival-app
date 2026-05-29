import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color appSeedColor = Color(0xFF2B3170); // CBF 2026: poster navy blue

TextTheme buildAppTextTheme(ColorScheme colorScheme) {
  final base = GoogleFonts.nunitoSansTextTheme();
  return base.copyWith(
    displayLarge: GoogleFonts.playfairDisplay(
      fontSize: 57,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    displayMedium: GoogleFonts.playfairDisplay(
      fontSize: 45,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    displaySmall: GoogleFonts.playfairDisplay(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    headlineLarge: GoogleFonts.playfairDisplay(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    headlineMedium: GoogleFonts.playfairDisplay(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    headlineSmall: GoogleFonts.playfairDisplay(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    titleLarge: GoogleFonts.playfairDisplay(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    titleMedium: GoogleFonts.nunitoSans(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    titleSmall: GoogleFonts.nunitoSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    bodyLarge: GoogleFonts.nunitoSans(
      fontSize: 16,
      color: colorScheme.onSurface,
    ),
    bodyMedium: GoogleFonts.nunitoSans(
      fontSize: 14,
      color: colorScheme.onSurface,
    ),
    bodySmall: GoogleFonts.nunitoSans(
      fontSize: 12,
      color: colorScheme.onSurfaceVariant,
    ),
    labelLarge: GoogleFonts.nunitoSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    labelMedium: GoogleFonts.nunitoSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    labelSmall: GoogleFonts.nunitoSans(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurfaceVariant,
    ),
  );
}

ThemeData buildAppTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: appSeedColor,
    brightness: brightness,
    primary: brightness == Brightness.light
        ? appSeedColor
        : const Color(0xFF8FA3E8),
    onPrimary: Colors.white,
  );
  final textTheme = buildAppTextTheme(colorScheme);
  return ThemeData(
    colorScheme: colorScheme,
    textTheme: textTheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: brightness == Brightness.light
          ? appSeedColor
          : colorScheme.surface,
      foregroundColor: brightness == Brightness.light
          ? Colors.white
          : colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: brightness == Brightness.light
            ? Colors.white
            : colorScheme.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: brightness == Brightness.light
          ? appSeedColor.withValues(alpha: 0.15)
          : colorScheme.primaryContainer,
    ),
  );
}
