import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';

// --- WCAG 2.1 contrast helpers (#637) ---------------------------------
//
// Implemented directly from the formula (no pub dependency), per
// https://www.w3.org/TR/WCAG21/#dfn-relative-luminance and
// https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio. `Color.r`/`.g`/`.b` are
// already normalised to 0.0-1.0 in this Flutter version, matching the
// formula's expected input directly.

/// sRGB channel (0.0-1.0) to linear light, the first step of relative
/// luminance.
double _srgbToLinear(double channel) {
  return channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

/// WCAG relative luminance of an opaque colour.
double _relativeLuminance(Color color) {
  return 0.2126 * _srgbToLinear(color.r) +
      0.7152 * _srgbToLinear(color.g) +
      0.0722 * _srgbToLinear(color.b);
}

/// WCAG contrast ratio between two opaque colours (1.0-21.0). Order-
/// independent, per the spec's own (lighter+0.05)/(darker+0.05) form.
double _contrastRatio(Color a, Color b) {
  final luminanceA = _relativeLuminance(a);
  final luminanceB = _relativeLuminance(b);
  final lighter = math.max(luminanceA, luminanceB);
  final darker = math.min(luminanceA, luminanceB);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Composite a translucent [fg] (painted at [alpha], 0.0-1.0) over an opaque
/// [bg] — standard "source over destination" alpha blending, matching what
/// `BoxDecoration(color: fg.withValues(alpha: alpha))` actually paints over
/// whatever sits behind it. Measuring [fg]'s own un-composited channels
/// against a background would silently compare a colour to itself (alpha
/// doesn't change r/g/b) and always report a meaningless ratio of 1.0 — every
/// translucent ground in this file goes through this first.
Color _compositeOver(Color fg, Color bg, double alpha) {
  return Color.from(
    alpha: 1.0,
    red: fg.r * alpha + bg.r * (1 - alpha),
    green: fg.g * alpha + bg.g * (1 - alpha),
    blue: fg.b * alpha + bg.b * (1 - alpha),
  );
}

/// Summed per-channel RGB distance between two colours, in 0-255 units.
/// A crude but stable proxy for "can a user tell these apart at 4px wide".
int _distance(Color a, Color b) {
  return (((a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs()) * 255)
      .round();
}

/// Every beverage type, as the `category` value its drinks actually carry —
/// the vocabulary [CategoryColorHelper.getAccentColor] is looked up by. Two
/// of the eight differ from their feed-file slug (#629), so this goes through
/// [BeverageCategories.feedCategoryFor] rather than listing the slugs.
final _categories = <String>[
  BeverageCategories.beer,
  BeverageCategories.internationalBeer,
  BeverageCategories.cider,
  BeverageCategories.perry,
  BeverageCategories.mead,
  BeverageCategories.wine,
  BeverageCategories.lowNo,
  BeverageCategories.appleJuice,
].map(BeverageCategories.feedCategoryFor).toList();

void main() {
  group('getAccentColor', () {
    test('light mode returns the fixed category hue', () {
      // Pinned so a derivation change cannot silently restyle light mode —
      // these are the values the committed light goldens were rendered from.
      expect(
        CategoryColorHelper.getAccentColor(
          BeverageCategories.beer,
          Brightness.light,
        ),
        const Color(0xFFF59E0B),
      );
      expect(
        CategoryColorHelper.getAccentColor(
          BeverageCategories.wine,
          Brightness.light,
        ),
        const Color(0xFF9333EA),
      );
    });

    test('international beer and apple juice are keyed by the category their '
        'drinks carry, not by the feed slug (#629)', () {
      // The regression: `_categoryHues` was keyed by the feed-file slugs
      // ('international-beer', 'apple-juice'), which Drink.category never
      // takes, so both entries were dead and every such drink fell back
      // to navy.
      const navy = Color(0xFF2B3170);
      expect(
        CategoryColorHelper.getAccentColor('foreign beer', Brightness.light),
        const Color(0xFFEF4444),
      );
      expect(
        CategoryColorHelper.getAccentColor('apple juice', Brightness.light),
        const Color(0xFF65A30D),
      );
      for (final category in ['foreign beer', 'apple juice']) {
        for (final brightness in Brightness.values) {
          expect(
            CategoryColorHelper.getAccentColor(category, brightness),
            isNot(
              CategoryColorHelper.getAccentColor('not-a-drink', brightness),
            ),
            reason: '$category should not be the fallback in $brightness',
          );
        }
      }
      // The feed values are the only keys — the slugs are not a second
      // vocabulary the helper also answers to.
      expect(
        CategoryColorHelper.getAccentColor(
          BeverageCategories.internationalBeer,
          Brightness.light,
        ),
        navy,
      );
    });

    test('dark mode lightens every category relative to light mode', () {
      for (final category in _categories) {
        final light = CategoryColorHelper.getAccentColor(
          category,
          Brightness.light,
        );
        final dark = CategoryColorHelper.getAccentColor(
          category,
          Brightness.dark,
        );
        expect(
          HSLColor.fromColor(dark).lightness,
          greaterThan(HSLColor.fromColor(light).lightness),
          reason: '$category should be lifted for a dark surface',
        );
      }
    });

    test('dark mode preserves hue, so a category stays recognisable', () {
      for (final category in _categories) {
        final lightHue = HSLColor.fromColor(
          CategoryColorHelper.getAccentColor(category, Brightness.light),
        ).hue;
        final darkHue = HSLColor.fromColor(
          CategoryColorHelper.getAccentColor(category, Brightness.dark),
        ).hue;
        expect(
          (lightHue - darkHue).abs(),
          lessThan(1.0),
          reason: '$category changed hue between light and dark',
        );
      }
    });

    // The regression this whole design exists to prevent: a derivation that
    // maps distinct categories onto the same colour. ColorScheme.fromSeed(...)
    // .primary was rejected precisely because it collapsed perry and apple
    // juice to a distance of 2.
    for (final brightness in Brightness.values) {
      test('all categories stay mutually distinguishable in $brightness', () {
        for (var i = 0; i < _categories.length; i++) {
          for (var j = i + 1; j < _categories.length; j++) {
            final a = CategoryColorHelper.getAccentColor(
              _categories[i],
              brightness,
            );
            final b = CategoryColorHelper.getAccentColor(
              _categories[j],
              brightness,
            );
            expect(
              _distance(a, b),
              greaterThan(50),
              reason:
                  '${_categories[i]} and ${_categories[j]} are too close to '
                  'tell apart in $brightness',
            );
          }
        }
      });
    }

    test('unknown category falls back to CBF navy, adapted per brightness', () {
      const navy = Color(0xFF2B3170);
      expect(
        CategoryColorHelper.getAccentColor('not-a-drink', Brightness.light),
        navy,
      );
      expect(
        CategoryColorHelper.getAccentColor('not-a-drink', Brightness.dark),
        isNot(navy),
      );
    });

    test('is pure — repeated calls agree', () {
      for (final category in _categories) {
        for (final brightness in Brightness.values) {
          expect(
            CategoryColorHelper.getAccentColor(category, brightness),
            CategoryColorHelper.getAccentColor(category, brightness),
          );
        }
      }
    });
  });

  group('getAvailabilityColor', () {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2B3170),
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2B3170),
      brightness: Brightness.dark,
    );

    test('returns the pinned pair for each fixed status', () {
      // These are the exact values hardcoded in _AvailabilityChip / the My
      // Festival at-risk hint; pinned so a palette edit is a deliberate
      // decision. Light-mode `plenty`/`good`/`low` were darkened by #637
      // (from 0xFF2E7D32/0xFF558B2F/0xFFEF6C00) to clear the WCAG AA 4.5:1
      // text-contrast minimum against the chip's own 10%-tint background —
      // see the 'availability chip and badge text contrast' group below for
      // the data-driven proof.
      const expected = <AvailabilityStatus, (Color, Color)>{
        AvailabilityStatus.plenty: (Color(0xFF226025), Color(0xFF4CAF50)),
        AvailabilityStatus.good: (Color(0xFF3F6A1E), Color(0xFF8BC34A)),
        AvailabilityStatus.low: (Color(0xFF9C4100), Color(0xFFFF9800)),
        AvailabilityStatus.veryLow: (Color(0xFFBF360C), Color(0xFFFF7043)),
        AvailabilityStatus.unknown: (Color(0xFF546E7A), Color(0xFF90A4AE)),
      };
      for (final entry in expected.entries) {
        expect(
          CategoryColorHelper.getAvailabilityColor(entry.key, lightScheme),
          entry.value.$1,
          reason: '${entry.key} light',
        );
        expect(
          CategoryColorHelper.getAvailabilityColor(entry.key, darkScheme),
          entry.value.$2,
          reason: '${entry.key} dark',
        );
      }
    });

    test('sold out tracks the theme error colour, not a fixed hex', () {
      expect(
        CategoryColorHelper.getAvailabilityColor(
          AvailabilityStatus.out,
          lightScheme,
        ),
        lightScheme.error,
      );
      expect(
        CategoryColorHelper.getAvailabilityColor(
          AvailabilityStatus.out,
          darkScheme,
        ),
        darkScheme.error,
      );
    });

    test('covers every AvailabilityStatus', () {
      for (final status in AvailabilityStatus.values) {
        expect(
          () => CategoryColorHelper.getAvailabilityColor(status, lightScheme),
          returnsNormally,
        );
      }
    });
  });

  group('availability chip and badge text contrast (#637)', () {
    // Both `_AvailabilityChip` (drink_card.dart) and `_AvailabilityHint`
    // (my_festival_screen.dart) render every AvailabilityStatus the same
    // way: an opaque, full-colour Text/Icon in `getAvailabilityColor(status,
    // colorScheme)`, inside a Container whose own background is that same
    // colour at `withValues(alpha: 0.1)` — i.e. the text's real background
    // is a 10%-tint composite, not whatever surface the chip happens to sit
    // on. Both widgets share one contract, so one data-driven check over the
    // enum covers both call sites.
    const chipTintAlpha = 0.1;
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2B3170),
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2B3170),
      brightness: Brightness.dark,
    );

    for (final brightness in Brightness.values) {
      final scheme = brightness == Brightness.dark ? darkScheme : lightScheme;

      test('every AvailabilityStatus clears 4.5:1 against its own '
          '10%-tint ground in $brightness', () {
        for (final status in AvailabilityStatus.values) {
          final text = CategoryColorHelper.getAvailabilityColor(status, scheme);
          final ground = _compositeOver(text, scheme.surface, chipTintAlpha);
          final ratio = _contrastRatio(text, ground);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$status in $brightness measured $ratio:1 for text '
                '$text over its composited chip ground $ground '
                '(scheme.surface ${scheme.surface} tinted at '
                '$chipTintAlpha) — below the WCAG AA small-text minimum',
          );
        }
      });
    }
  });

  group('festival status badge text contrast (#637)', () {
    // FestivalStatusBadge (festival_header.dart) paints its label directly
    // on the opaque fill Container.decoration.color returns — no translucent
    // layer, so the fill itself is the ground; no compositing needed here.
    for (final brightness in Brightness.values) {
      test(
        'every FestivalStatus fill/on-fill pair clears 4.5:1 in $brightness',
        () {
          for (final status in FestivalStatus.values) {
            final (fill, onFill) = CategoryColorHelper.getFestivalStatusColors(
              status,
              brightness,
            );
            final ratio = _contrastRatio(onFill, fill);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason:
                  '$status badge in $brightness measured $ratio:1 for '
                  'on-fill $onFill over fill $fill — below the WCAG AA '
                  'small-text minimum (badge text is 9-10px, no large-text '
                  'exemption applies)',
            );
          }
        },
      );
    }
  });

  group('getTastedColor', () {
    test('differs by brightness', () {
      expect(
        CategoryColorHelper.getTastedColor(Brightness.light),
        const Color(0xFF2E7D32),
      );
      expect(
        CategoryColorHelper.getTastedColor(Brightness.dark),
        const Color(0xFF4CAF50),
      );
    });
  });
}
