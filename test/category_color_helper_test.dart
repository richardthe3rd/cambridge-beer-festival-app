import 'package:cambridge_beer_festival/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryColorHelper', () {
    /// Pumps a [Builder] under [brightness] and captures the colour the helper
    /// returns for [category] alongside the active colour scheme.
    Future<(Color result, ColorScheme scheme)> resolve(
      WidgetTester tester,
      Brightness brightness,
      String category,
    ) async {
      late Color result;
      late ColorScheme scheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              result = CategoryColorHelper.getCategoryColor(context, category);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (result, scheme);
    }

    testWidgets('beer categories use the secondary colour', (tester) async {
      final (result, scheme) = await resolve(tester, Brightness.light, 'beer');
      expect(result, scheme.secondary);
    });

    testWidgets('international-beer still matches the beer branch', (
      tester,
    ) async {
      final (result, scheme) = await resolve(
        tester,
        Brightness.light,
        'international-beer',
      );
      expect(result, scheme.secondary);
    });

    testWidgets('cider has a dedicated colour per theme', (tester) async {
      final (light, _) = await resolve(tester, Brightness.light, 'cider');
      expect(light, const Color(0xFF689F38));

      final (dark, _) = await resolve(tester, Brightness.dark, 'cider');
      expect(dark, const Color(0xFF8BC34A).withValues(alpha: 0.8));
    });

    testWidgets('perry has a dedicated colour', (tester) async {
      final (result, _) = await resolve(tester, Brightness.light, 'perry');
      expect(result, const Color(0xFFAFB42B));
    });

    testWidgets('mead has a dedicated colour', (tester) async {
      final (result, _) = await resolve(tester, Brightness.light, 'mead');
      expect(result, const Color(0xFFF9A825));
    });

    testWidgets('wine has a dedicated colour', (tester) async {
      final (result, _) = await resolve(tester, Brightness.light, 'wine');
      expect(result, const Color(0xFF7B1FA2));
    });

    testWidgets('low-no categories use the primary colour', (tester) async {
      final (result, scheme) = await resolve(
        tester,
        Brightness.light,
        'low-no',
      );
      expect(result, scheme.primary);
    });

    testWidgets('matching is case-insensitive', (tester) async {
      final (result, scheme) = await resolve(tester, Brightness.light, 'BEER');
      expect(result, scheme.secondary);
    });

    testWidgets('unknown categories fall back to the outline colour', (
      tester,
    ) async {
      final (result, scheme) = await resolve(
        tester,
        Brightness.light,
        'spirits',
      );
      expect(result, scheme.outline);
    });
  });
}
