import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cambridge_beer_festival/app_theme.dart';

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
        final background = theme.appBarTheme.backgroundColor!;
        final title = theme.appBarTheme.titleTextStyle!.color!;
        double channel(double v) => v <= 0.03928
            ? v / 12.92
            : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
        double luminance(Color c) =>
            0.2126 * channel(c.r) +
            0.7152 * channel(c.g) +
            0.0722 * channel(c.b);
        final lt = luminance(title);
        final lb = luminance(background);
        final ratio =
            ((lt > lb ? lt : lb) + 0.05) / ((lt > lb ? lb : lt) + 0.05);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '$brightness app bar title is only '
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
}
