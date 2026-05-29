import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cambridge_beer_festival/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('buildAppTheme', () {
    testWidgets('light theme uses navy seed colour as AppBar background', (
      WidgetTester tester,
    ) async {
      final theme = buildAppTheme(Brightness.light);
      expect(theme.appBarTheme.backgroundColor, equals(appSeedColor));
    });

    testWidgets('light theme uses white as AppBar foreground', (
      WidgetTester tester,
    ) async {
      final theme = buildAppTheme(Brightness.light);
      expect(theme.appBarTheme.foregroundColor, equals(Colors.white));
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
