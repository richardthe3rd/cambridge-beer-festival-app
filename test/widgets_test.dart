import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';

void main() {
  group('StarRating', () {
    testWidgets('displays 5 stars', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRating(),
          ),
        ),
      );

      // Should find 5 star icons (star_border since no rating)
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('displays filled stars based on rating', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRating(rating: 3),
          ),
        ),
      );

      // Should find 3 filled stars and 2 empty stars
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    });

    testWidgets('displays all filled stars for rating of 5', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRating(rating: 5),
          ),
        ),
      );

      // Should find 5 filled stars and no empty stars
      expect(find.byIcon(Icons.star), findsNWidgets(5));
      expect(find.byIcon(Icons.star_border), findsNothing);
    });

    testWidgets('displays all empty stars for null rating', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRating(rating: null),
          ),
        ),
      );

      // Should find 5 empty stars
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('calls onRatingChanged when editable star is tapped', (WidgetTester tester) async {
      int? selectedRating;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRating(
              isEditable: true,
              onRatingChanged: (rating) => selectedRating = rating,
            ),
          ),
        ),
      );

      // Tap the third star (index 2)
      final stars = find.byType(GestureDetector);
      expect(stars, findsNWidgets(5));

      await tester.tap(stars.at(2));
      await tester.pump();

      expect(selectedRating, 3);
    });

    testWidgets('tapping first star sets rating to 1', (WidgetTester tester) async {
      int? selectedRating;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRating(
              isEditable: true,
              onRatingChanged: (rating) => selectedRating = rating,
            ),
          ),
        ),
      );

      final stars = find.byType(GestureDetector);
      await tester.tap(stars.at(0));
      await tester.pump();

      expect(selectedRating, 1);
    });

    testWidgets('tapping fifth star sets rating to 5', (WidgetTester tester) async {
      int? selectedRating;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRating(
              isEditable: true,
              onRatingChanged: (rating) => selectedRating = rating,
            ),
          ),
        ),
      );

      final stars = find.byType(GestureDetector);
      await tester.tap(stars.at(4));
      await tester.pump();

      expect(selectedRating, 5);
    });

    testWidgets('does not call onRatingChanged when not editable', (WidgetTester tester) async {
      int? selectedRating;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRating(
              isEditable: false,
              onRatingChanged: (rating) => selectedRating = rating,
            ),
          ),
        ),
      );

      final stars = find.byType(GestureDetector);
      await tester.tap(stars.at(2));
      await tester.pump();

      expect(selectedRating, isNull);
    });

    testWidgets('uses custom star size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRating(starSize: 48),
          ),
        ),
      );

      final iconFinder = find.byIcon(Icons.star_border);
      final iconWidget = tester.widget<Icon>(iconFinder.first);
      expect(iconWidget.size, 48);
    });

    testWidgets('uses custom active color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRating(
              rating: 1,
              activeColor: Colors.red,
            ),
          ),
        ),
      );

      final filledStar = find.byIcon(Icons.star);
      final iconWidget = tester.widget<Icon>(filledStar.first);
      expect(iconWidget.color, Colors.red);
    });

    testWidgets('uses custom inactive color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRating(
              rating: 1,
              inactiveColor: Colors.blue,
            ),
          ),
        ),
      );

      final emptyStar = find.byIcon(Icons.star_border);
      final iconWidget = tester.widget<Icon>(emptyStar.first);
      expect(iconWidget.color, Colors.blue);
    });

    testWidgets('tapping same star clears rating', (WidgetTester tester) async {
      int? selectedRating;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRating(
              rating: 3,
              isEditable: true,
              onRatingChanged: (rating) => selectedRating = rating,
            ),
          ),
        ),
      );

      // Tap the third star (index 2) - same as current rating
      final stars = find.byType(GestureDetector);
      await tester.tap(stars.at(2));
      await tester.pump();

      // Should clear the rating (set to null)
      expect(selectedRating, isNull);
    });

    testWidgets('tapping different star changes rating', (WidgetTester tester) async {
      int? selectedRating;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRating(
              rating: 3,
              isEditable: true,
              onRatingChanged: (rating) => selectedRating = rating,
            ),
          ),
        ),
      );

      // Tap the fifth star (index 4) - different from current rating
      final stars = find.byType(GestureDetector);
      await tester.tap(stars.at(4));
      await tester.pump();

      // Should change to rating 5
      expect(selectedRating, 5);
    });

    testWidgets('tapping star when rating is null sets rating', (WidgetTester tester) async {
      int? selectedRating;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRating(
              rating: null,
              isEditable: true,
              onRatingChanged: (rating) => selectedRating = rating,
            ),
          ),
        ),
      );

      // Tap the fourth star (index 3)
      final stars = find.byType(GestureDetector);
      await tester.tap(stars.at(3));
      await tester.pump();

      // Should set rating to 4
      expect(selectedRating, 4);
    });

    testWidgets('tapping first star when rating is 1 clears rating', (WidgetTester tester) async {
      int? selectedRating;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRating(
              rating: 1,
              isEditable: true,
              onRatingChanged: (rating) => selectedRating = rating,
            ),
          ),
        ),
      );

      // Tap the first star (index 0) - same as current rating
      final stars = find.byType(GestureDetector);
      await tester.tap(stars.at(0));
      await tester.pump();

      // Should clear the rating
      expect(selectedRating, isNull);
    });

    testWidgets('tapping fifth star when rating is 5 clears rating', (WidgetTester tester) async {
      int? selectedRating;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRating(
              rating: 5,
              isEditable: true,
              onRatingChanged: (rating) => selectedRating = rating,
            ),
          ),
        ),
      );

      // Tap the fifth star (index 4) - same as current rating
      final stars = find.byType(GestureDetector);
      await tester.tap(stars.at(4));
      await tester.pump();

      // Should clear the rating
      expect(selectedRating, isNull);
    });

    testWidgets('editable rating includes clear instruction in semantic hint', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRating(
              rating: 3,
              isEditable: true,
            ),
          ),
        ),
      );

      // Find the Semantics widget and check its properties
      final semantics = tester.widget<Semantics>(
        find.ancestor(
          of: find.byType(Row),
          matching: find.byType(Semantics),
        ).first,
      );

      // Verify the hint mentions clearing
      expect(semantics.properties.hint, contains('clear'));
      expect(semantics.properties.hint, contains('Tap again'));
    });

    testWidgets('non-editable rating does not include hint', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRating(
              rating: 3,
              isEditable: false,
            ),
          ),
        ),
      );

      // Find the Semantics widget and check its properties
      final semantics = tester.widget<Semantics>(
        find.ancestor(
          of: find.byType(Row),
          matching: find.byType(Semantics),
        ).first,
      );

      // Verify there's no hint for non-editable ratings
      expect(semantics.properties.hint, isNull);
    });
  });
}
