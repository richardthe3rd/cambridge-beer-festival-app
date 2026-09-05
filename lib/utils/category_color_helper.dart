import 'package:flutter/material.dart';
import '../models/models.dart';

/// The app's colour system: the single source of truth for every colour used
/// as a *signal* rather than as chrome.
///
/// Three independent signals live here, deliberately kept separate so they can
/// evolve without dragging each other along:
///
/// | Signal            | Accessor                 | Derivation                     |
/// |-------------------|--------------------------|--------------------------------|
/// | Beverage category | [getAccentColor]         | fixed hue, lightened for dark  |
/// | Stock level       | [getAvailabilityColor]   | fixed pair + theme error       |
/// | Personal status   | [getTastedColor]         | fixed pair                     |
///
/// Colour is always a *supplementary* aid here — never the sole carrier of
/// meaning. Every surface that uses these also carries an icon or a text label,
/// so none of these values is subject to WCAG text-contrast minima (none has
/// text drawn on top of it; accents are 4px decorative edges).
///
/// Do not hardcode any of these hex values at a call site. Adding one here and
/// referencing it is the whole point of this class.
class CategoryColorHelper {
  CategoryColorHelper._();

  /// Source hue per beverage type, keyed by the feed-file slug for
  /// readability — also the literal light-mode accent.
  ///
  /// These are hand-picked to stay mutually distinguishable at a 4px width:
  /// the closest pair (beer/mead) sits ~72 units apart in summed RGB distance.
  /// If you add a category, check it does not collide with an existing hue —
  /// `category_color_helper_test.dart` pins a minimum separation.
  static const Map<String, Color> _hueBySlug = {
    BeverageCategories.beer: Color(0xFFF59E0B), // amber
    BeverageCategories.internationalBeer: Color(0xFFEF4444), // red
    BeverageCategories.cider: Color(0xFF22C55E), // green
    BeverageCategories.perry: Color(0xFF84CC16), // lime
    BeverageCategories.mead: Color(0xFFD97706), // honey gold
    BeverageCategories.wine: Color(0xFF9333EA), // purple
    BeverageCategories.lowNo: Color(0xFF06B6D4), // cyan
    BeverageCategories.appleJuice: Color(0xFF65A30D), // apple green
  };

  /// [_hueBySlug] re-keyed onto the `category` value each drink actually
  /// carries, which is what [getAccentColor] is looked up by.
  ///
  /// The two vocabularies differ for international beer (`foreign beer`) and
  /// apple juice (`apple juice`); keying the lookup by slug left both entries
  /// dead and every such drink on the fallback navy (#629). The mapping is
  /// owned by [BeverageCategories.feedCategoryFor] so the divergence is
  /// recorded in exactly one place.
  static final Map<String, Color> _categoryHues = {
    for (final entry in _hueBySlug.entries)
      BeverageCategories.feedCategoryFor(entry.key): entry.value,
  };

  /// Accent for an unrecognised category — CBF poster navy, matching
  /// `appSeedColor`.
  static const Color _fallbackHue = Color(0xFF2B3170);

  /// Lightness added / saturation retained when adapting a hue for a dark
  /// surface. Tuned so the lifted palette keeps roughly the separation of the
  /// light one rather than washing out to pastel.
  static const double _darkLightnessLift = 0.18;
  static const double _darkSaturationScale = 0.92;

  /// Adapt a light-mode hue for a dark surface by lifting its lightness while
  /// preserving hue.
  ///
  /// Deliberately *not* `ColorScheme.fromSeed(...).primary`: that maps every
  /// hue onto a Material tonal role, which desaturates the palette and — as
  /// measured — collapses perry and apple juice onto the same colour, which
  /// defeats the point of a per-category accent.
  static Color _liftForDark(Color hue) {
    final hsl = HSLColor.fromColor(hue);
    return hsl
        .withLightness((hsl.lightness + _darkLightnessLift).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * _darkSaturationScale).clamp(0.0, 1.0))
        .toColor();
  }

  /// Solid accent colour for a beverage [category], used for the 4px coloured
  /// left edge shared by the drink list card, the hero panels, the My Festival
  /// rows and the similar-drinks carousel.
  ///
  /// Derived from [brightness]: the fixed hue in light mode, a lightness-lifted
  /// variant in dark mode so the edge reads against a dark surface.
  ///
  /// An unrecognised category falls back to CBF navy, which is adapted for
  /// dark surfaces the same way a real category is — so the dark fallback is a
  /// lifted navy, not the navy literal.
  static Color getAccentColor(String category, Brightness brightness) {
    final hue = _categoryHues[category] ?? _fallbackHue;
    return brightness == Brightness.dark ? _liftForDark(hue) : hue;
  }

  /// The most common category among [drinks] (by drink count) — used to pick
  /// a single accent colour for an entity that can span categories (a
  /// brewery's lineup, or a style whose name happens to be reused across
  /// categories). Ties resolve to whichever category appears first in
  /// [drinks]' order, keeping the result deterministic. Callers must pass a
  /// non-empty list.
  static String dominantCategory(List<Drink> drinks) {
    assert(drinks.isNotEmpty, 'dominantCategory requires a non-empty list');
    final counts = <String, int>{};
    for (final drink in drinks) {
      counts[drink.category] = (counts[drink.category] ?? 0) + 1;
    }
    var dominant = '';
    var best = 0;
    for (final drink in drinks) {
      final count = counts[drink.category]!;
      if (count > best) {
        best = count;
        dominant = drink.category;
      }
    }
    return dominant;
  }

  /// Colour for a stock-level [status], shared by the drinks list availability
  /// chip and the My Festival at-risk hint.
  ///
  /// [AvailabilityStatus.out] resolves to the theme's semantic error colour
  /// rather than a fixed hex — "sold out" is the one availability state that
  /// should track the app's error language, so [colorScheme] is required.
  /// Every other state uses a fixed light/dark pair chosen for legibility on
  /// both surfaces.
  ///
  /// Brightness is read from [colorScheme] rather than taken separately, so a
  /// caller cannot pass a dark scheme alongside a light brightness.
  static Color getAvailabilityColor(
    AvailabilityStatus status,
    ColorScheme colorScheme,
  ) {
    final isDark = colorScheme.brightness == Brightness.dark;
    switch (status) {
      case AvailabilityStatus.plenty:
        return isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);
      case AvailabilityStatus.good:
        return isDark ? const Color(0xFF8BC34A) : const Color(0xFF558B2F);
      case AvailabilityStatus.low:
        return isDark ? const Color(0xFFFF9800) : const Color(0xFFEF6C00);
      case AvailabilityStatus.veryLow:
        return isDark ? const Color(0xFFFF7043) : const Color(0xFFBF360C);
      case AvailabilityStatus.out:
        return colorScheme.error;
      case AvailabilityStatus.unknown:
        return isDark ? const Color(0xFF90A4AE) : const Color(0xFF546E7A);
    }
  }

  /// The "tasted" indicator green, shared by the drink card status badge, the
  /// drink detail hero and the My Festival rows. Darker in light mode for
  /// contrast, lighter in dark mode.
  ///
  /// Independent of [getAvailabilityColor] by design: personal status and
  /// stock level are separate signals and may diverge visually later, even
  /// though `plenty` happens to use the same green today.
  static Color getTastedColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xFF4CAF50)
        : const Color(0xFF2E7D32);
  }
}
