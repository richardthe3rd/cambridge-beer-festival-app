import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';
import 'package:cambridge_beer_festival/widgets/star_rating.dart';

// --- WCAG 2.1 contrast helpers (#648) -----------------------------------
//
// Same formula as `test/category_color_helper_test.dart` (#637), duplicated
// here per this repo's per-file `createSample{Model}()` convention for test
// fixtures — see https://www.w3.org/TR/WCAG21/#dfn-relative-luminance and
// https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio. `Color.r`/`.g`/`.b` are
// already normalised to 0.0-1.0 in this Flutter version.

double _srgbToLinear(double channel) {
  return channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(Color color) {
  return 0.2126 * _srgbToLinear(color.r) +
      0.7152 * _srgbToLinear(color.g) +
      0.0722 * _srgbToLinear(color.b);
}

double _contrastRatio(Color a, Color b) {
  final luminanceA = _relativeLuminance(a);
  final luminanceB = _relativeLuminance(b);
  final lighter = math.max(luminanceA, luminanceB);
  final darker = math.min(luminanceA, luminanceB);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  Widget buildWidget({
    int? rating,
    bool isEditable = false,
    ValueChanged<int?>? onRatingChanged,
    double starSize = 24,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StarRating(
          rating: rating,
          isEditable: isEditable,
          onRatingChanged: onRatingChanged,
          starSize: starSize,
        ),
      ),
    );
  }

  group('StarRating', () {
    group('star rendering', () {
      testWidgets('renders exactly 5 stars', (tester) async {
        await tester.pumpWidget(buildWidget());
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      });

      testWidgets('shows N filled stars for rating N', (tester) async {
        for (var n = 1; n <= 5; n++) {
          await tester.pumpWidget(buildWidget(rating: n));
          expect(find.byIcon(Icons.star), findsNWidgets(n));
          expect(find.byIcon(Icons.star_border), findsNWidgets(5 - n));
        }
      });

      testWidgets('shows all 5 filled stars for rating 5', (tester) async {
        await tester.pumpWidget(buildWidget(rating: 5));
        expect(find.byIcon(Icons.star), findsNWidgets(5));
        expect(find.byIcon(Icons.star_border), findsNothing);
      });
    });

    group('semantics', () {
      SemanticsNode outerSemantics(WidgetTester tester) => tester.getSemantics(
        find
            .ancestor(of: find.byType(Row), matching: find.byType(Semantics))
            .first,
      );

      testWidgets('outer label is "Rate this drink" when editable', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(isEditable: true));
        expect(outerSemantics(tester).label, 'Rate this drink');
      });

      testWidgets('outer label is "Rating" when not editable', (tester) async {
        await tester.pumpWidget(buildWidget(rating: 3));
        expect(outerSemantics(tester).label, 'Rating');
      });

      testWidgets('semantic value reflects current rating', (tester) async {
        await tester.pumpWidget(buildWidget(rating: 3));
        expect(outerSemantics(tester).value, '3 out of 5 stars');
      });

      testWidgets('semantic value is "0 out of 5 stars" when unrated', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        expect(outerSemantics(tester).value, '0 out of 5 stars');
      });

      testWidgets('hint text present when editable', (tester) async {
        await tester.pumpWidget(buildWidget(isEditable: true));
        expect(outerSemantics(tester).hint, isNotEmpty);
      });

      testWidgets('no hint text when not editable', (tester) async {
        await tester.pumpWidget(buildWidget(rating: 2));
        expect(outerSemantics(tester).hint, isEmpty);
      });

      testWidgets('stars are marked as buttons when editable', (tester) async {
        await tester.pumpWidget(buildWidget(isEditable: true));
        final node = tester.getSemantics(
          find
              .descendant(
                of: find.byType(StarRating),
                matching: find.byType(Semantics),
              )
              .at(1),
        );
        expect(node.flagsCollection.isButton, isTrue);
      });

      testWidgets('stars are not marked as buttons when not editable', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        final node = tester.getSemantics(
          find
              .descendant(
                of: find.byType(StarRating),
                matching: find.byType(Semantics),
              )
              .at(1),
        );
        expect(node.flagsCollection.isButton, isFalse);
      });
    });

    group('tap interactions', () {
      testWidgets('tapping star N calls onRatingChanged with N', (
        tester,
      ) async {
        int? received;
        await tester.pumpWidget(
          buildWidget(isEditable: true, onRatingChanged: (v) => received = v),
        );

        await tester.tap(
          find
              .descendant(
                of: find.byType(StarRating),
                matching: find.byType(GestureDetector),
              )
              .at(2),
        );
        expect(received, 3);
      });

      testWidgets('tapping the current rating clears it (calls with null)', (
        tester,
      ) async {
        int? received = -1;
        await tester.pumpWidget(
          buildWidget(
            rating: 3,
            isEditable: true,
            onRatingChanged: (v) => received = v,
          ),
        );

        await tester.tap(
          find
              .descendant(
                of: find.byType(StarRating),
                matching: find.byType(GestureDetector),
              )
              .at(2),
        );
        expect(received, isNull);
      });

      testWidgets('tapping different star updates rating', (tester) async {
        int? received;
        await tester.pumpWidget(
          buildWidget(
            rating: 3,
            isEditable: true,
            onRatingChanged: (v) => received = v,
          ),
        );

        await tester.tap(
          find
              .descendant(
                of: find.byType(StarRating),
                matching: find.byType(GestureDetector),
              )
              .at(4),
        );
        expect(received, 5);
      });

      testWidgets('tapping does nothing when not editable', (tester) async {
        var called = false;
        await tester.pumpWidget(
          buildWidget(rating: 3, onRatingChanged: (_) => called = true),
        );

        await tester.tap(find.byIcon(Icons.star).first);
        expect(called, isFalse);
      });
    });

    group('display options', () {
      testWidgets('respects custom starSize', (tester) async {
        await tester.pumpWidget(buildWidget(rating: 1, starSize: 32));

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.size, 32);
      });

      testWidgets('respects custom activeColor', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StarRating(rating: 1, activeColor: Colors.red),
            ),
          ),
        );

        final filledIcon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(filledIcon.color, Colors.red);
      });

      // Two separate testWidgets (light/dark), not one test looping
      // Brightness.values with pumpWidget calls that differ only in theme —
      // the const Scaffold/StarRating subtree below would be `identical()`
      // across pumps, so Flutter's element diffing skips rebuilding it and
      // the second pump silently keeps the first pump's resolved colour.
      testWidgets(
        'default active colour is CategoryColorHelper.getRatingColor in '
        'light mode, not Colors.amber',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(Brightness.light),
              home: const Scaffold(body: StarRating(rating: 1)),
            ),
          );

          final filledIcon = tester.widget<Icon>(find.byIcon(Icons.star));
          expect(
            filledIcon.color,
            CategoryColorHelper.getRatingColor(Brightness.light),
          );
        },
      );

      testWidgets(
        'default active colour is CategoryColorHelper.getRatingColor in '
        'dark mode',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(Brightness.dark),
              home: const Scaffold(body: StarRating(rating: 1)),
            ),
          );

          final filledIcon = tester.widget<Icon>(find.byIcon(Icons.star));
          expect(
            filledIcon.color,
            CategoryColorHelper.getRatingColor(Brightness.dark),
          );
        },
      );

      testWidgets('explicit activeColor still overrides the default in '
          'light mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const Scaffold(
              body: StarRating(rating: 1, activeColor: Colors.red),
            ),
          ),
        );

        final filledIcon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(filledIcon.color, Colors.red);
      });

      testWidgets('explicit activeColor still overrides the default in '
          'dark mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(Brightness.dark),
            home: const Scaffold(
              body: StarRating(rating: 1, activeColor: Colors.red),
            ),
          ),
        );

        final filledIcon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(filledIcon.color, Colors.red);
      });
    });

    group('getRatingColor contrast (#648)', () {
      // WCAG 1.4.11 requires 3:1 for the parts of a control that convey
      // state — the filled-star glyph here. Colors.amber (the old default in
      // both brightnesses) measured ~1.6:1 against the light surface; this
      // is the regression guard. A test that only pinned hex values would
      // pass even if someone later picked a new colour that still fails the
      // contrast minimum, so the point of this group is the computed ratio,
      // not the literal.
      test('light and dark values are the documented pinned pair', () {
        expect(
          CategoryColorHelper.getRatingColor(Brightness.light),
          const Color(0xFFCC7000),
        );
        expect(
          CategoryColorHelper.getRatingColor(Brightness.dark),
          Colors.amber,
        );
      });

      for (final brightness in Brightness.values) {
        test('clears WCAG 1.4.11\'s 3:1 non-text minimum against the '
            'resolved surface in $brightness', () {
          final colorScheme = buildAppTheme(brightness).colorScheme;
          final star = CategoryColorHelper.getRatingColor(brightness);

          // `colorScheme.surface` — the plain app background the "Your
          // Take" card's StarRating (starSize 30) sits behind via its own
          // default M3 Card fill.
          final onSurface = _contrastRatio(star, colorScheme.surface);
          // `colorScheme.surfaceContainerLow` — the default M3 `Card`
          // colour (verified against the Flutter SDK's
          // `_CardDefaultsM3.color`), which is what the drink card's
          // StarRating (starSize 14) actually renders on and is darker
          // than `colorScheme.surface`. This is the worst case.
          final onSurfaceContainerLow = _contrastRatio(
            star,
            colorScheme.surfaceContainerLow,
          );

          expect(
            onSurface,
            greaterThanOrEqualTo(3.0),
            reason:
                'getRatingColor($brightness) = $star measured '
                '$onSurface:1 against colorScheme.surface '
                '${colorScheme.surface}',
          );
          expect(
            onSurfaceContainerLow,
            greaterThanOrEqualTo(3.0),
            reason:
                'getRatingColor($brightness) = $star measured '
                '$onSurfaceContainerLow:1 against '
                'colorScheme.surfaceContainerLow '
                '${colorScheme.surfaceContainerLow} — the drink card '
                "rating chip's actual background",
          );
        });
      }
    });
  });
}
