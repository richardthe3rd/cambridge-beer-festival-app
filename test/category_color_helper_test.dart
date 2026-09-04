import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';

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
      // These are the exact values previously hardcoded in _AvailabilityChip;
      // pinned so the consolidation stays a pure move, not a restyle.
      const expected = <AvailabilityStatus, (Color, Color)>{
        AvailabilityStatus.plenty: (Color(0xFF2E7D32), Color(0xFF4CAF50)),
        AvailabilityStatus.good: (Color(0xFF558B2F), Color(0xFF8BC34A)),
        AvailabilityStatus.low: (Color(0xFFEF6C00), Color(0xFFFF9800)),
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
