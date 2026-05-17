import 'package:cambridge_beer_festival/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ABVStrengthHelper', () {
    group('getABVStrengthLabel', () {
      test('returns (Low) below 4.0%', () {
        expect(ABVStrengthHelper.getABVStrengthLabel(0.0), '(Low)');
        expect(ABVStrengthHelper.getABVStrengthLabel(3.9), '(Low)');
      });

      test('returns (Medium) from 4.0% up to but not including 7.0%', () {
        expect(ABVStrengthHelper.getABVStrengthLabel(4.0), '(Medium)');
        expect(ABVStrengthHelper.getABVStrengthLabel(6.9), '(Medium)');
      });

      test('returns (High) at 7.0% and above', () {
        expect(ABVStrengthHelper.getABVStrengthLabel(7.0), '(High)');
        expect(ABVStrengthHelper.getABVStrengthLabel(12.0), '(High)');
      });
    });

    group('getABVColor', () {
      /// Pumps a [Builder] under [brightness] and captures the colour the
      /// helper returns for [abv] alongside the active colour scheme.
      Future<(Color result, ColorScheme scheme)> resolve(
        WidgetTester tester,
        Brightness brightness,
        double abv,
      ) async {
        late Color result;
        late ColorScheme scheme;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Builder(
              builder: (context) {
                scheme = Theme.of(context).colorScheme;
                result = ABVStrengthHelper.getABVColor(context, abv);
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        return (result, scheme);
      }

      testWidgets('low ABV uses the primary colour (light theme)',
          (tester) async {
        final (result, scheme) = await resolve(tester, Brightness.light, 3.0);
        expect(result, scheme.primary);
      });

      testWidgets('low ABV dims the primary colour (dark theme)',
          (tester) async {
        final (result, scheme) = await resolve(tester, Brightness.dark, 3.0);
        expect(result, scheme.primary.withValues(alpha: 0.7));
      });

      testWidgets('medium ABV uses the secondary colour (light theme)',
          (tester) async {
        final (result, scheme) = await resolve(tester, Brightness.light, 5.0);
        expect(result, scheme.secondary);
      });

      testWidgets('medium ABV dims the secondary colour (dark theme)',
          (tester) async {
        final (result, scheme) = await resolve(tester, Brightness.dark, 5.0);
        expect(result, scheme.secondary.withValues(alpha: 0.8));
      });

      testWidgets('high ABV uses deep orange (light theme)', (tester) async {
        final (result, _) = await resolve(tester, Brightness.light, 8.0);
        expect(result, const Color(0xFFE64A19));
      });

      testWidgets('high ABV uses translucent deep orange (dark theme)',
          (tester) async {
        final (result, _) = await resolve(tester, Brightness.dark, 8.0);
        expect(result, const Color(0xFFFF5722).withValues(alpha: 0.85));
      });
    });
  });
}
