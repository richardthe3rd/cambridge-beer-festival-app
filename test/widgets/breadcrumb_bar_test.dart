import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BreadcrumbBar', () {
    testWidgets('renders back button and label', (tester) async {
      var backPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              onBack: () => backPressed = true,
            ),
          ),
        ),
      );

      // Find back button
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Find label text
      expect(find.text('Beer'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(backPressed, isTrue);
    });

    testWidgets('renders with context text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              contextLabel: 'Oakham Ales',
              onBack: () {},
            ),
          ),
        ),
      );

      // Find combined text
      expect(find.text('Beer / Oakham Ales'), findsOneWidget);
    });

    testWidgets('handles long text with ellipsis', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200, // Constrain width to force overflow
              child: BreadcrumbBar(
                backLabel: 'Beer',
                contextLabel: 'Very Long Brewery Name That Should Overflow',
                onBack: () {},
              ),
            ),
          ),
        ),
      );

      // Find text widget
      final textWidget = tester.widget<Text>(
        find.text('Beer / Very Long Brewery Name That Should Overflow'),
      );

      // Verify overflow behavior
      expect(textWidget.overflow, equals(TextOverflow.ellipsis));
      expect(textWidget.maxLines, equals(1));
    });

    testWidgets('has correct semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              contextLabel: 'Oakham Ales',
              onBack: () {},
            ),
          ),
        ),
      );

      // Find the Semantics widget with our custom label
      final allSemantics = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byType(BreadcrumbBar),
          matching: find.byType(Semantics),
        ),
      );

      // Filter to find our custom Semantics (has our label and button property)
      final customSemantics = allSemantics.where((s) =>
          s.properties.label == 'Back to Beer' &&
          s.properties.button == true);

      // Should have exactly one
      expect(customSemantics.length, equals(1));

      // Verify semantic properties
      final semantics = customSemantics.first;
      expect(semantics.properties.label, 'Back to Beer');
      expect(semantics.properties.button, isTrue);
    });

    testWidgets('back button has tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              onBack: () {},
            ),
          ),
        ),
      );

      // Find IconButton
      final iconButton = tester.widget<IconButton>(
        find.byType(IconButton),
      );

      // Verify tooltip
      expect(iconButton.tooltip, equals('Back to Beer'));
    });

    testWidgets('calls onBack when back button is pressed', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              onBack: () => callCount++,
            ),
          ),
        ),
      );

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(callCount, equals(1));

      // Tap again
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(callCount, equals(2));
    });

    testWidgets('handles very long backLabel', (tester) async {
      final longLabel = 'x' * 100;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: BreadcrumbBar(
                backLabel: longLabel,
                onBack: () {},
              ),
            ),
          ),
        ),
      );

      // Widget should render without overflow errors
      expect(find.byType(BreadcrumbBar), findsOneWidget);
    });

    testWidgets('handles Unicode characters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer 🍺',
              contextLabel: 'Oktoberfest Märzen',
              onBack: () {},
            ),
          ),
        ),
      );

      expect(find.text('Beer 🍺 / Oktoberfest Märzen'), findsOneWidget);
    });

    testWidgets('semantics only wraps IconButton, not Text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              contextLabel: 'Oakham Ales',
              onBack: () {},
            ),
          ),
        ),
      );

      // Find the Semantics widget with our custom label
      final allSemantics = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byType(BreadcrumbBar),
          matching: find.byType(Semantics),
        ),
      );

      // Filter to find our custom Semantics (has our label and button property)
      final customSemantics = allSemantics.where((s) =>
          s.properties.label == 'Back to Beer' &&
          s.properties.button == true);

      // Should have exactly one custom Semantics widget
      expect(customSemantics.length, equals(1));
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      var counter = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              onBack: () => counter++,
            ),
          ),
        ),
      );

      // First tap
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(counter, equals(1));

      // Rebuild widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              onBack: () => counter++,
            ),
          ),
        ),
      );

      // Second tap after rebuild
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(counter, equals(2));
    });
  });
}
