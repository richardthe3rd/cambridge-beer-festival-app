import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cambridge_beer_festival/app_theme.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two colours, order-independent (always >= 1).
double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
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

    testWidgets('AppBar title contrasts with its background in both themes', (
      WidgetTester tester,
    ) async {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(brightness);
        final ratio = _contrastRatio(
          theme.appBarTheme.titleTextStyle!.color!,
          theme.appBarTheme.backgroundColor!,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '$brightness app bar title is only '
              '${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

    // `onPrimary` used to be hardcoded to white, which measured ~2.45:1
    // against the dark `primary` (0xFF8FA3E8) — the defect this test exists to
    // stop returning. The pair renders on `FilledButton.icon`
    // (festival_info_screen.dart) and on any filled button.
    testWidgets('primary contrasts with onPrimary in both themes', (
      WidgetTester tester,
    ) async {
      for (final brightness in Brightness.values) {
        final scheme = buildAppTheme(brightness).colorScheme;
        final ratio = _contrastRatio(scheme.onPrimary, scheme.primary);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '$brightness primary/onPrimary is only '
              '${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

    // The pair the drinks filter buttons render: they set a
    // `primaryContainer` background, so they must set the matching
    // foreground rather than inheriting FilledButton.tonal's
    // `onSecondaryContainer`.
    testWidgets('primaryContainer contrasts with onPrimaryContainer', (
      WidgetTester tester,
    ) async {
      for (final brightness in Brightness.values) {
        final scheme = buildAppTheme(brightness).colorScheme;
        final ratio = _contrastRatio(
          scheme.onPrimaryContainer,
          scheme.primaryContainer,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '$brightness primaryContainer/onPrimaryContainer is only '
              '${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

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
