import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const Color appSeedColor = Color(0xFF2B3170); // CBF 2026: poster navy blue

/// A post-generation override for one or more [ColorScheme] roles.
///
/// A top-level function tear-off (not a closure) so [AppColorTheme] instances
/// referencing one can stay `const`.
typedef SchemeRefinement = ColorScheme Function(ColorScheme generated);

/// A user-selectable colour theme: a seed colour plus a Material 3 dynamic
/// scheme variant, with an optional [refine] step for roles generation alone
/// doesn't get right. Generation and explicit pinning are two ends of one
/// dial — [ColorScheme.fromSeed] itself accepts dozens of optional overrides
/// — rather than competing designs.
///
/// [id] is persisted to `PreferenceKeys.themePalette` and must never change
/// once shipped; doing so orphans every stored preference under the old
/// value (see `AppColorTheme` catalogue below for the fallback behaviour).
class AppColorTheme {
  const AppColorTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.seed,
    this.variant = DynamicSchemeVariant.tonalSpot,
    this.refine,
  });

  /// Stable identifier persisted to SharedPreferences.
  final String id;

  /// Display name shown in the theme picker.
  final String name;

  /// One-line description shown under [name] in the theme picker.
  final String description;

  /// Seed colour generation starts from.
  final Color seed;

  /// Material 3 dynamic scheme variant used for generation.
  final DynamicSchemeVariant variant;

  /// Optional post-generation override for specific roles.
  final SchemeRefinement? refine;

  /// Generates the [ColorScheme] for this theme at [brightness], applying
  /// [refine] if present.
  ColorScheme scheme(Brightness brightness) {
    final generated = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: variant,
    );
    return refine?.call(generated) ?? generated;
  }
}

/// Pins `primary` to the exact CBF poster navy in light mode and the lighter
/// blue already used for dark mode, matching the brand colour precisely
/// rather than letting generation retune it.
///
/// `onPrimary` is deliberately left to generate rather than pinned to
/// `Colors.white`: the former hardcoded white measured ~2.45:1 against dark
/// `primary` (0xFF8FA3E8) — well under the WCAG AA 4.5:1 bar (issue #596).
/// Letting `onPrimary` generate fixes that contrast defect for free.
ColorScheme _refineCbfNavy(ColorScheme generated) {
  return generated.copyWith(
    primary: generated.brightness == Brightness.light
        ? const Color(0xFF2B3170)
        : const Color(0xFF8FA3E8),
  );
}

/// The default colour theme: the festival's own poster navy.
const AppColorTheme cbfNavyTheme = AppColorTheme(
  id: 'cbfNavy',
  name: 'CBF Navy',
  description: 'The festival poster navy.',
  seed: Color(0xFF2B3170),
  variant: DynamicSchemeVariant.tonalSpot,
  refine: _refineCbfNavy,
);

/// Restores the tonal relationship every other theme gets for free.
///
/// `monochrome` drives the primary roles to the extremes and inverts
/// `primaryContainer` against its own surface — measured: a near-white
/// #D4D4D4 container on a #131313 dark surface, and a near-black #3B3B3B
/// container on a #F9F9F9 light one. That turns the festival hero into the
/// brightest object on a dark screen, and into a solid dark slab on a light
/// one — the same pattern deliberately removed from the light app bar (see
/// [buildAppTheme]). Pure white/black `primary` is likewise hotter than the
/// tone every other theme lands on.
///
/// These pins keep Chalk greyscale while letting its containers recede
/// toward their surface, the way CBF Navy's do (#596).
ColorScheme _refineChalk(ColorScheme generated) {
  final isDark = generated.brightness == Brightness.dark;
  return generated.copyWith(
    primary: isDark ? const Color(0xFFE2E2E2) : const Color(0xFF2E2E2E),
    onPrimary: isDark ? const Color(0xFF1B1B1B) : const Color(0xFFF5F5F5),
    primaryContainer: isDark
        ? const Color(0xFF3B3B3B)
        : const Color(0xFFE2E2E2),
    onPrimaryContainer: isDark
        ? const Color(0xFFE2E2E2)
        : const Color(0xFF1B1B1B),
  );
}

/// Greyscale chrome — the only colour anywhere on screen then carries
/// meaning (category edges, availability, tasted state). Named for the
/// festival's own price boards.
const AppColorTheme chalkTheme = AppColorTheme(
  id: 'chalk',
  name: 'Chalk',
  description: 'Greyscale, so colour always means something.',
  seed: Color(0xFF6E6A63),
  variant: DynamicSchemeVariant.monochrome,
  refine: _refineChalk,
);

/// Every colour theme a user can pick, in display (and picker) order. A
/// list, not a map, so a new theme appends without disturbing the others.
const List<AppColorTheme> appColorThemes = <AppColorTheme>[
  cbfNavyTheme,
  chalkTheme,
];

/// The theme applied when no preference has been stored yet.
const AppColorTheme defaultAppColorTheme = cbfNavyTheme;

/// Resolves a stored `PreferenceKeys.themePalette` [id] to its
/// [AppColorTheme]. An unknown or missing id falls back to
/// [defaultAppColorTheme] — mirrors the bounds-clamp already used for the
/// stored theme-mode index in `UserPreferencesController.hydrate`.
AppColorTheme appColorThemeById(String? id) {
  for (final theme in appColorThemes) {
    if (theme.id == id) return theme;
  }
  return defaultAppColorTheme;
}

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

/// Builds the app's [ThemeData] for [brightness] from [colorTheme].
///
/// [colorTheme] defaults to [defaultAppColorTheme] (CBF Navy) so every
/// existing single-argument call site keeps building the same default theme
/// it always has.
ThemeData buildAppTheme(
  Brightness brightness, [
  AppColorTheme colorTheme = defaultAppColorTheme,
]) {
  final colorScheme = colorTheme.scheme(brightness);
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
          ? colorTheme.seed.withValues(alpha: 0.15)
          : colorScheme.primaryContainer,
    ),
  );
}
