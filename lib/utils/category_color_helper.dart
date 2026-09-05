import 'package:flutter/material.dart';
import '../models/models.dart';

/// The app's colour system: the single source of truth for every colour used
/// as a *signal* rather than as chrome.
///
/// Four independent signals live here, deliberately kept separate so they can
/// evolve without dragging each other along:
///
/// | Signal            | Accessor                    | Derivation                     |
/// |--------------------|-----------------------------|--------------------------------|
/// | Beverage category  | [getAccentColor]            | fixed hue, lightened for dark  |
/// | Stock level        | [getAvailabilityColor]      | fixed pair + theme error       |
/// | Personal status     | [getTastedColor]            | fixed pair                     |
/// | Festival status     | [getFestivalStatusColors]   | fixed fill/on-fill pairs       |
///
/// Colour is always a *supplementary* aid here — never the sole carrier of
/// meaning; every surface that uses these also carries an icon or a text
/// label. But **not every accessor is decorative**: [getAccentColor] is a 4px
/// edge with nothing drawn on top of it and is exempt from WCAG's text-contrast
/// minima, but [getAvailabilityColor] is drawn as the *text* of the drinks-list
/// and My-Festival availability chips (over a 10% tint of itself), and
/// [getFestivalStatusColors] returns a fill *and* the on-colour drawn as the
/// festival-status badge's text — both are held to the 4.5:1 AA minimum for
/// small text and are covered by the data-driven contrast test in
/// `test/category_color_helper_test.dart` (#637). [getTastedColor] is drawn
/// as text too — the drink card's tasting-count label and the hero panel's
/// "Available" fact value — but directly on the surface rather than over a
/// tint, and it clears 4.5:1 there; that is pinned by the same test rather
/// than asserted here, which is the mistake this doc used to make.
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
  /// chip and the My Festival at-risk hint. Both callers draw this **as the
  /// chip's text** (over a `withValues(alpha: 0.1)` tint of the same colour) —
  /// so, unlike [getAccentColor], every value here must clear the WCAG AA
  /// 4.5:1 small-text minimum against that tint. See
  /// `test/category_color_helper_test.dart` for the data-driven proof (#637).
  ///
  /// [AvailabilityStatus.out] resolves to the theme's semantic error colour
  /// rather than a fixed hex — "sold out" is the one availability state that
  /// should track the app's error language, so [colorScheme] is required.
  /// Every other state uses a fixed light/dark pair chosen for legibility on
  /// both surfaces.
  ///
  /// [AvailabilityStatus.low] and [AvailabilityStatus.good] were both below
  /// 4.5:1 in light mode until #637 (`#EF6C00` measured ~3.1:1, `#558B2F`
  /// ~4.1:1 against the app surface) — darkened here, hue preserved, to
  /// `#9C4100` / `#3F6A1E`. While proving those two with the composited
  /// ground the fix demands, [AvailabilityStatus.plenty]'s light value
  /// (`#2E7D32`) also measured under 4.5:1 (~4.3:1) once its own 10%-tint is
  /// properly composited over `ColorScheme.surface` rather than assumed pure
  /// white — darkened alongside the other two, to `#226025`, same hue. Every
  /// other light value and all dark values already cleared 4.5:1 against
  /// that same composited ground and are unchanged.
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
        return isDark ? const Color(0xFF4CAF50) : const Color(0xFF226025);
      case AvailabilityStatus.good:
        return isDark ? const Color(0xFF8BC34A) : const Color(0xFF3F6A1E);
      case AvailabilityStatus.low:
        return isDark ? const Color(0xFFFF9800) : const Color(0xFF9C4100);
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

  /// Dark ink used as the on-colour for every dark-mode festival-status badge
  /// fill (see [getFestivalStatusColors]) — a single shared value rather than
  /// a per-status one, since all four dark fills are light/mid-tone enough
  /// that one dark ink clears 4.5:1 against each with room to spare.
  static const Color _festivalBadgeOnDark = Color(0xFF212121);

  /// Fill and on-fill (text) colour for a [FestivalStatus] badge — `(fill,
  /// onFill)` — shared by the app-bar header badge and the larger badge used
  /// on the festival browser cards and info screen (both render through
  /// `FestivalStatusBadge`).
  ///
  /// Before #637 every badge drew white text on [fill] unconditionally; four
  /// of the eight fill/brightness combinations measured below the WCAG AA
  /// 4.5:1 minimum for the badge's 9-10px bold text (RECENT light ~3.1:1, and
  /// LIVE/SOON/RECENT/PAST all ~2.2-3.0:1 in dark mode, white text sitting
  /// directly on the fill with no intervening tint). The fix pairs each fill
  /// with its own on-colour instead of assuming white:
  /// - Light mode: LIVE/SOON/PAST fills were already >=4.5:1 with white text
  ///   and keep white; RECENT's fill is darkened (`#EF6C00` -> `#B85300`) —
  ///   white text on the lighter fill was ~3.1:1.
  /// - Dark mode: every fill keeps its existing colour (the palette's
  ///   dark-surface hues are deliberately lighter/more saturated than their
  ///   light counterparts) but pairs with [_festivalBadgeOnDark] instead of
  ///   white, since white on any of the four dark fills was under 3:1.
  ///
  /// See `test/category_color_helper_test.dart` for the data-driven contrast
  /// proof over every (status, brightness) combination.
  static (Color, Color) getFestivalStatusColors(
    FestivalStatus status,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    switch (status) {
      case FestivalStatus.live:
        return isDark
            ? (const Color(0xFF4CAF50), _festivalBadgeOnDark)
            : (const Color(0xFF2E7D32), Colors.white);
      case FestivalStatus.upcoming:
        return isDark
            ? (const Color(0xFF42A5F5), _festivalBadgeOnDark)
            : (const Color(0xFF1976D2), Colors.white);
      case FestivalStatus.mostRecent:
        return isDark
            ? (const Color(0xFFFF9800), _festivalBadgeOnDark)
            : (const Color(0xFFB85300), Colors.white);
      case FestivalStatus.past:
        return isDark
            ? (const Color(0xFF9E9E9E), _festivalBadgeOnDark)
            : (const Color(0xFF616161), Colors.white);
    }
  }
}
