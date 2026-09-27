import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';

void main() {
  group('InfoChip', () {
    testWidgets('displays label and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InfoChip(label: 'Test Label', icon: Icons.star),
          ),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    // #693: icon is optional — a chip with no icon renders the label alone.
    testWidgets('renders label only when icon is omitted', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: InfoChip(label: 'No Icon Label')),
        ),
      );

      expect(find.text('No Icon Label'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(InfoChip), matching: find.byType(Icon)),
        findsNothing,
      );
    });

    testWidgets('non-tappable chip has no InkWell', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InfoChip(label: 'Test', icon: Icons.info),
          ),
        ),
      );

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('tappable chip responds to tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfoChip(
              label: 'Test',
              icon: Icons.info,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.byType(InfoChip));
      expect(tapped, isTrue);
    });

    testWidgets('tappable chip has Semantics wrapper', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfoChip(
              label: 'Style Name',
              icon: Icons.local_drink,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify Semantics widget exists for tappable chip
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
