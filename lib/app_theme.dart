import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const Color appSeedColor = Color(0xFF2B3170); // CBF 2026: poster navy blue

/// The SIL Open Font License texts shipped alongside the bundled typefaces in
/// `assets/fonts/`, keyed by the licence entry name shown to users.
@visibleForTesting
const Map<String, String> fontLicenseAssets = <String, String>{
  'Nunito Sans': 'assets/fonts/OFL-NunitoSans.txt',
  'Playfair Display': 'assets/fonts/OFL-PlayfairDisplay.txt',
};

/// Reads each licence in [fontLicenseAssets] out of the asset bundle.
///
/// Split out from [registerFontLicenses] so tests can consume the stream
/// directly — draining the global `LicenseRegistry.licenses` never completes
/// under `flutter_test`.
@visibleForTesting
Stream<LicenseEntry> loadFontLicenses() async* {
  for (final MapEntry<String, String> entry in fontLicenseAssets.entries) {
    final String license = await rootBundle.loadString(entry.value);
    yield LicenseEntryWithLineBreaks(<String>[entry.key], license);
  }
}

/// Registers the OFL licences for the fonts bundled in `assets/fonts/` so they
/// appear in the app's "View licences" page.
///
/// Bundling the font binaries (rather than letting `google_fonts` fetch them
/// from fonts.gstatic.com) means the app redistributes them, and the SIL Open
/// Font License requires the licence to travel with the files. Call this from
/// `main()` before `runApp`.
void registerFontLicenses() {
  LicenseRegistry.addLicense(loadFontLicenses);
}

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
    // `primary` is pinned so the brand navy is exact, but `onPrimary` is left
    // to generate. Hardcoding it to white measured ~2.45:1 against the dark
    // `primary` (0xFF8FA3E8) — well under WCAG AA's 4.5:1, and it renders on
    // `FilledButton.icon` (festival_info_screen.dart). Generation places it at
    // a guaranteed tonal distance instead. Light mode is unaffected: the
    // generated value there is white already.
    primary: brightness == Brightness.light
        ? appSeedColor
        : const Color(0xFF8FA3E8),
  );
  final textTheme = buildAppTextTheme(colorScheme);
  return ThemeData(
    colorScheme: colorScheme,
    textTheme: textTheme,
    useMaterial3: true,
    // The app bar is a plain Material 3 surface in both themes. Light mode
    // previously used the poster navy as a solid slab, which made it the only
    // dark surface in an otherwise light UI; the brand colour still leads
    // through `primary`, the nav bar indicator and the category accents.
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: brightness == Brightness.light
          ? appSeedColor.withValues(alpha: 0.15)
          : colorScheme.primaryContainer,
    ),
  );
}
