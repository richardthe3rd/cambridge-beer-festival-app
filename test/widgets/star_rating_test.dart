import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/widgets/star_rating.dart';

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
      outerSemantics(WidgetTester tester) => tester.getSemantics(
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
        expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
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
        expect(node.hasFlag(SemanticsFlag.isButton), isFalse);
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
          MaterialApp(
            home: Scaffold(
              body: StarRating(rating: 1, activeColor: Colors.red),
            ),
          ),
        );

        final filledIcon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(filledIcon.color, Colors.red);
      });
    });
  });
}
