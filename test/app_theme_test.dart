import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';

/// Every beverage category with a fixed accent hue — mirrors `_categories`
/// in `category_color_helper_test.dart`.
const _categoriesForHueTest = <String>[
  BeverageCategories.beer,
  BeverageCategories.internationalBeer,
  BeverageCategories.cider,
  BeverageCategories.perry,
  BeverageCategories.mead,
  BeverageCategories.wine,
  BeverageCategories.lowNo,
  BeverageCategories.appleJuice,
];

/// WCAG relative-luminance sRGB channel transform.
double _srgbChannel(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _relativeLuminance(Color c) =>
    0.2126 * _srgbChannel(c.r) +
    0.7152 * _srgbChannel(c.g) +
    0.0722 * _srgbChannel(c.b);

/// WCAG contrast ratio between two colours, order-independent (always >= 1).
double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('buildAppTheme', () {
    // The light app bar used to be a solid navy slab, which made it the only
    // dark surface in an otherwise light UI. It is now a plain Material 3
    // surface in both themes; the seed colour still leads via `primary`, the
    // nav bar indicator and the category accents.
    testWidgets('light theme AppBar background is surface (not navy)', (
      WidgetTester tester,
    ) async {
      final theme = buildAppTheme(Brightness.light);
      expect(theme.appBarTheme.backgroundColor, isNot(equals(appSeedColor)));
      expect(
        theme.appBarTheme.backgroundColor,
        equals(theme.colorScheme.surface),
      );
    });

    testWidgets('light theme AppBar foreground is onSurface', (
      WidgetTester tester,
    ) async {
      final theme = buildAppTheme(Brightness.light);
      expect(theme.appBarTheme.foregroundColor, isNot(equals(Colors.white)));
      expect(
        theme.appBarTheme.foregroundColor,
        equals(theme.colorScheme.onSurface),
      );
    });

    // Generalized per issue #596: loops every theme in the catalogue x
    // Brightness.values. This is the mechanism that makes a hand-pinned role
    // (like CBF Navy's `primary`) safe — a new theme, or a new pin on an
    // existing one, cannot ship with a silent contrast regression.
    for (final colorTheme in appColorThemes) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '${colorTheme.name} AppBar title contrasts with its background '
          '($brightness)',
          (WidgetTester tester) async {
            final theme = buildAppTheme(brightness, colorTheme);
            final ratio = _contrastRatio(
              theme.appBarTheme.titleTextStyle!.color!,
              theme.appBarTheme.backgroundColor!,
            );
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason:
                  '${colorTheme.name} $brightness app bar title is only '
                  '${ratio.toStringAsFixed(2)}:1',
            );
          },
        );

        testWidgets('${colorTheme.name} primaryContainer contrasts with '
            'onPrimaryContainer ($brightness)', (WidgetTester tester) async {
          final scheme = buildAppTheme(brightness, colorTheme).colorScheme;
          final ratio = _contrastRatio(
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${colorTheme.name} $brightness '
                'primaryContainer/onPrimaryContainer is only '
                '${ratio.toStringAsFixed(2)}:1',
          );
        });

        // Pins down issue #596's Navy dark defect: the old hardcoded
        // `onPrimary: Colors.white` measured ~2.45:1 against dark `primary`
        // (0xFF8FA3E8) — under the 4.5:1 bar.
        testWidgets(
          '${colorTheme.name} primary contrasts with onPrimary ($brightness)',
          (WidgetTester tester) async {
            final theme = buildAppTheme(brightness, colorTheme);
            final ratio = _contrastRatio(
              theme.colorScheme.onPrimary,
              theme.colorScheme.primary,
            );
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason:
                  '${colorTheme.name} $brightness primary/onPrimary is only '
                  '${ratio.toStringAsFixed(2)}:1',
            );
          },
        );
      }
    }

    testWidgets('light theme primary colour equals seed colour', (
      WidgetTester tester,
    ) async {
      final theme = buildAppTheme(Brightness.light);
      expect(theme.colorScheme.primary, equals(appSeedColor));
    });

    testWidgets('dark theme AppBar background is surface (not navy)', (
      WidgetTester tester,
    ) async {
      final lightTheme = buildAppTheme(Brightness.light);
      final darkTheme = buildAppTheme(Brightness.dark);
      expect(
        darkTheme.appBarTheme.backgroundColor,
        isNot(equals(appSeedColor)),
      );
      expect(
        darkTheme.appBarTheme.backgroundColor,
        equals(darkTheme.colorScheme.surface),
      );
      expect(
        darkTheme.appBarTheme.backgroundColor,
        isNot(equals(lightTheme.appBarTheme.backgroundColor)),
      );
    });

    testWidgets('dark theme primary colour is lighter blue (not navy)', (
      WidgetTester tester,
    ) async {
      final darkTheme = buildAppTheme(Brightness.dark);
      expect(darkTheme.colorScheme.primary, isNot(equals(appSeedColor)));
    });

    testWidgets('AppBar has zero elevation', (WidgetTester tester) async {
      expect(buildAppTheme(Brightness.light).appBarTheme.elevation, equals(0));
      expect(buildAppTheme(Brightness.dark).appBarTheme.elevation, equals(0));
    });

    testWidgets('AppBar title is not centered', (WidgetTester tester) async {
      expect(buildAppTheme(Brightness.light).appBarTheme.centerTitle, isFalse);
      expect(buildAppTheme(Brightness.dark).appBarTheme.centerTitle, isFalse);
    });

    testWidgets('uses Material 3', (WidgetTester tester) async {
      expect(buildAppTheme(Brightness.light).useMaterial3, isTrue);
      expect(buildAppTheme(Brightness.dark).useMaterial3, isTrue);
    });
  });

  group('buildAppTextTheme', () {
    testWidgets('returns a TextTheme with display styles set', (
      WidgetTester tester,
    ) async {
      final colorScheme = ColorScheme.fromSeed(
        seedColor: appSeedColor,
        brightness: Brightness.light,
      );
      final textTheme = buildAppTextTheme(colorScheme);
      expect(textTheme.displayLarge, isNotNull);
      expect(textTheme.displayLarge!.fontSize, equals(57));
    });

    testWidgets('titleLarge has correct font size', (
      WidgetTester tester,
    ) async {
      final colorScheme = ColorScheme.fromSeed(
        seedColor: appSeedColor,
        brightness: Brightness.light,
      );
      final textTheme = buildAppTextTheme(colorScheme);
      expect(textTheme.titleLarge!.fontSize, equals(22));
    });

    testWidgets('bodyMedium has correct font size', (
      WidgetTester tester,
    ) async {
      final colorScheme = ColorScheme.fromSeed(
        seedColor: appSeedColor,
        brightness: Brightness.light,
      );
      final textTheme = buildAppTextTheme(colorScheme);
      expect(textTheme.bodyMedium!.fontSize, equals(14));
    });
  });

  group('appSeedColor', () {
    test('is the CBF 2026 navy', () {
      expect(appSeedColor, equals(const Color(0xFF2B3170)));
    });
  });

  group('theme seed hue separation from category colours', () {
    // A theme seed tints app chrome broadly, while CategoryColorHelper's hues
    // are a 4px accent signal (drink category). If a seed lands too close to
    // a category hue, the accent stops reading as distinct from the chrome.
    // Desaturated seeds are exempt: a near-grey seed (e.g. a monochrome
    // theme) never reads as a colour regardless of its nominal hue angle, so
    // it cannot collide with a hue-based signal — mirrors the category
    // separation test's own "can a user tell these apart" framing in
    // category_color_helper_test.dart.
    const minHueDegrees = 25.0;
    const minSeedSaturation = 0.15;

    double hueDistance(Color a, Color b) {
      final diff = (HSLColor.fromColor(a).hue - HSLColor.fromColor(b).hue)
          .abs();
      return diff > 180 ? 360 - diff : diff;
    }

    for (final colorTheme in appColorThemes) {
      final seedSaturation = HSLColor.fromColor(colorTheme.seed).saturation;
      if (seedSaturation < minSeedSaturation) continue;

      for (final category in _categoriesForHueTest) {
        test('${colorTheme.name} stays >= $minHueDegrees° from $category', () {
          final categoryHue = CategoryColorHelper.getAccentColor(
            category,
            Brightness.light,
          );
          expect(
            hueDistance(colorTheme.seed, categoryHue),
            greaterThanOrEqualTo(minHueDegrees),
            reason:
                '${colorTheme.name} seed is too close in hue to the '
                '$category accent',
          );
        });
      }
    }
  });

  group('AppColorTheme catalogue', () {
    test('every theme has a unique id', () {
      final ids = appColorThemes.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('contains exactly the three shipped themes', () {
      expect(appColorThemes.map((t) => t.id), ['cbfNavy', 'chalk', 'damson']);
    });

    test('defaultAppColorTheme is CBF Navy', () {
      expect(defaultAppColorTheme.id, 'cbfNavy');
    });

    test('cbfNavy pins primary only, per theme', () {
      final light = cbfNavyTheme.scheme(Brightness.light);
      final dark = cbfNavyTheme.scheme(Brightness.dark);
      expect(light.primary, const Color(0xFF2B3170));
      expect(dark.primary, const Color(0xFF8FA3E8));
    });

    test('chalk pins primary and container roles, per theme', () {
      final light = chalkTheme.scheme(Brightness.light);
      final dark = chalkTheme.scheme(Brightness.dark);
      // The container must sit on the same side of the surface as its own
      // brightness — the inversion #596 fixed. Asserted as a relationship,
      // not as literals, so a retune cannot silently reintroduce it.
      expect(
        light.primaryContainer.computeLuminance(),
        greaterThan(0.5),
        reason: 'light primaryContainer must stay light, not invert to a slab',
      );
      expect(
        dark.primaryContainer.computeLuminance(),
        lessThan(0.5),
        reason: 'dark primaryContainer must stay dark, not invert to a slab',
      );
    });

    test('damson leaves primary to generation (no pin)', () {
      for (final theme in [damsonTheme]) {
        for (final brightness in Brightness.values) {
          final generated = ColorScheme.fromSeed(
            seedColor: theme.seed,
            brightness: brightness,
            dynamicSchemeVariant: theme.variant,
          );
          expect(theme.scheme(brightness).primary, generated.primary);
        }
      }
    });

    group('appColorThemeById', () {
      test('resolves a known id', () {
        expect(appColorThemeById('chalk').id, 'chalk');
        expect(appColorThemeById('damson').id, 'damson');
      });

      test('falls back to the default for an unknown id', () {
        expect(appColorThemeById('not-a-theme').id, 'cbfNavy');
      });

      test('falls back to the default for a null id', () {
        expect(appColorThemeById(null).id, 'cbfNavy');
      });
    });
  });

  group('registerFontLicenses', () {
    // The font binaries in assets/fonts/ are redistributed under the SIL Open
    // Font License, so the licence text has to ship with them. These tests load
    // the real assets — a typo in a path would make them fail rather than
    // silently register an empty licence.
    //
    // Asset reads go through `tester.runAsync`: inside testWidgets' FakeAsync
    // zone a `rootBundle` load never completes, and the test hangs until the
    // 10-minute timeout instead of failing.
    testWidgets('every declared licence asset exists and is the OFL', (
      WidgetTester tester,
    ) async {
      expect(fontLicenseAssets, isNotEmpty);

      for (final MapEntry<String, String> entry in fontLicenseAssets.entries) {
        final String? text = await tester.runAsync(
          () => rootBundle.loadString(entry.value),
        );
        expect(
          text,
          contains('SIL Open Font License'),
          reason: '${entry.key} licence asset should be the OFL',
        );
      }
    });

    test('covers every bundled font family', () {
      // If a third family is ever bundled, its licence must be registered too.
      expect(
        fontLicenseAssets.keys,
        containsAll(<String>['Nunito Sans', 'Playfair Display']),
      );
    });

    testWidgets('feeds the entries into the LicenseRegistry', (
      WidgetTester tester,
    ) async {
      // Drop Flutter's own collectors so the registry yields only ours.
      LicenseRegistry.reset();
      addTearDown(LicenseRegistry.reset);

      registerFontLicenses();

      // runAsync escapes testWidgets' fake-async zone. The collector awaits a
      // real asset read, which never completes on the fake clock — draining it
      // directly hangs until the 10-minute test timeout.
      final List<LicenseEntry>? entries = await tester.runAsync(
        () => LicenseRegistry.licenses.toList(),
      );

      expect(
        entries!.expand((LicenseEntry entry) => entry.packages),
        containsAll(fontLicenseAssets.keys),
      );
    });

    testWidgets('yields one licence entry per family, carrying its text', (
      WidgetTester tester,
    ) async {
      // Drains the collector directly, bypassing the global registry.
      final List<LicenseEntry>? entries = await tester.runAsync(
        () => loadFontLicenses().toList(),
      );

      expect(entries, isNotNull);
      expect(entries!, hasLength(fontLicenseAssets.length));
      expect(
        entries.expand((LicenseEntry entry) => entry.packages),
        containsAll(fontLicenseAssets.keys),
      );
      for (final LicenseEntry entry in entries) {
        expect(
          entry.paragraphs.first.text,
          contains('Copyright'),
          reason: 'licence entry for ${entry.packages} should carry its text',
        );
      }
    });
  });
}
