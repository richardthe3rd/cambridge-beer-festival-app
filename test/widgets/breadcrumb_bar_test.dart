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
              context: 'Oakham Ales',
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
                context: 'Very Long Brewery Name That Should Overflow',
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
    });

    testWidgets('has correct semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Beer',
              context: 'Oakham Ales',
              onBack: () {},
            ),
          ),
        ),
      );

      // Find Semantics widget that wraps the BreadcrumbBar
      final semanticsFinder = find.descendant(
        of: find.byType(BreadcrumbBar),
        matching: find.byType(Semantics),
      );

      expect(semanticsFinder, findsWidgets);

      final semantics = tester.widget<Semantics>(semanticsFinder.first);

      // Verify semantic properties
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
  });
}
