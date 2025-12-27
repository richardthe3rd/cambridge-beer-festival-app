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

      // Find individual text segments
      expect(find.text('Beer'), findsOneWidget);
      expect(find.text(' / '), findsOneWidget);
      expect(find.text('Oakham Ales'), findsOneWidget);
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

      // Find individual text widgets (text is now split into segments)
      final backLabelText = tester.widget<Text>(find.text('Beer'));
      final contextLabelText = tester.widget<Text>(
        find.text('Very Long Brewery Name That Should Overflow'),
      );

      // Verify overflow behavior on both text segments
      expect(backLabelText.overflow, equals(TextOverflow.ellipsis));
      expect(backLabelText.maxLines, equals(1));
      expect(contextLabelText.overflow, equals(TextOverflow.ellipsis));
      expect(contextLabelText.maxLines, equals(1));
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

      // Text is now split into separate segments
      expect(find.text('Beer 🍺'), findsOneWidget);
      expect(find.text(' / '), findsOneWidget);
      expect(find.text('Oktoberfest Märzen'), findsOneWidget);
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

    testWidgets('calls onBackLabelTap when back label is tapped', (tester) async {
      var backLabelTapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Drinks',
              onBack: () {},
              onBackLabelTap: () => backLabelTapCount++,
            ),
          ),
        ),
      );

      // Tap directly on the 'Drinks' text which should be wrapped in InkWell
      await tester.tap(find.text('Drinks'));
      expect(backLabelTapCount, equals(1));
    });

    testWidgets('calls onContextLabelTap when context label is tapped', (tester) async {
      var contextLabelTapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Drinks',
              contextLabel: 'Oakham Ales',
              onBack: () {},
              onContextLabelTap: () => contextLabelTapCount++,
            ),
          ),
        ),
      );

      // Tap directly on the 'Oakham Ales' text which should be wrapped in InkWell
      await tester.tap(find.text('Oakham Ales'));
      expect(contextLabelTapCount, equals(1));
    });

    testWidgets('both labels are clickable when both callbacks provided', (tester) async {
      var backLabelTaps = 0;
      var contextLabelTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Drinks',
              contextLabel: 'Oakham Ales',
              onBack: () {},
              onBackLabelTap: () => backLabelTaps++,
              onContextLabelTap: () => contextLabelTaps++,
            ),
          ),
        ),
      );

      // Tap the 'Drinks' text
      await tester.tap(find.text('Drinks'));
      expect(backLabelTaps, equals(1));
      expect(contextLabelTaps, equals(0));

      // Tap the 'Oakham Ales' text
      await tester.tap(find.text('Oakham Ales'));
      expect(backLabelTaps, equals(1));
      expect(contextLabelTaps, equals(1));
    });

    testWidgets('text is not clickable when callbacks not provided', (tester) async {
      var backTapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Drinks',
              contextLabel: 'Oakham Ales',
              onBack: () => backTapCount++,
            ),
          ),
        ),
      );

      // Tapping the text should not trigger any navigation
      // (only the back button should work)
      await tester.tap(find.text('Drinks'));
      await tester.tap(find.text('Oakham Ales'));

      // Back button tap count should still be 0
      expect(backTapCount, equals(0));
    });

    testWidgets('clickable labels have semantic properties', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Drinks',
              contextLabel: 'Oakham Ales',
              onBack: () {},
              onBackLabelTap: () {},
              onContextLabelTap: () {},
            ),
          ),
        ),
      );

      // Find all Semantics widgets
      final allSemantics = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );

      // Filter to find navigation semantics (button=true, label starts with 'Navigate to')
      final navigationSemantics = allSemantics.where((s) =>
          s.properties.button == true &&
          s.properties.label?.startsWith('Navigate to') == true);

      // Should have two navigation semantics (back label + context label)
      expect(navigationSemantics.length, equals(2));

      // Check labels
      final labels = navigationSemantics.map((s) => s.properties.label).toList();
      expect(labels, contains('Navigate to Drinks'));
      expect(labels, contains('Navigate to Oakham Ales'));
    });

    testWidgets('separator text is not clickable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              backLabel: 'Drinks',
              contextLabel: 'Oakham Ales',
              onBack: () {},
              onBackLabelTap: () {},
              onContextLabelTap: () {},
            ),
          ),
        ),
      );

      // Find the separator text
      expect(find.text(' / '), findsOneWidget);

      // Verify separator exists and is displayed
      final separatorText = tester.widget<Text>(find.text(' / '));
      expect(separatorText.data, equals(' / '));
    });
  });
}
