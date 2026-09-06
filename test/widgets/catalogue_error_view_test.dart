import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogueErrorView', () {
    testWidgets(
      'renders the error message and a Retry button that calls back',
      (tester) async {
        var retried = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CatalogueErrorView(
                error: 'Server error. Please try again later.',
                onRetry: () => retried = true,
              ),
            ),
          ),
        );

        expect(find.text('Error loading drinks'), findsOneWidget);
        expect(
          find.text('Server error. Please try again later.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
        expect(retried, isTrue);
      },
    );

    testWidgets('the Retry button has a meaningful Semantics label and hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogueErrorView(error: 'boom', onRetry: () {}),
          ),
        ),
      );

      // Asserted through the real semantics pipeline, not by reading
      // Semantics widget properties: a properties-only assertion cannot see
      // how a node merges with its children, which is where announcement
      // regressions actually show up (same reason as #609).
      final handle = tester.ensureSemantics();
      try {
        final node = tester.getSemantics(
          find.byKey(const ValueKey('catalogue-error-retry')),
        );
        expect(node.label, 'Retry loading drinks');
        expect(node.hint, 'Double tap to reload festival data');
        expect(node.flagsCollection.isButton, isTrue);
      } finally {
        handle.dispose();
      }
    });
  });
}
