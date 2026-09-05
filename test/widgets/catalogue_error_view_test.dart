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

      final labelled = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.label == 'Retry loading drinks')
          .toList();

      expect(labelled, hasLength(1));
      expect(labelled.single.properties.button, isTrue);
      expect(labelled.single.properties.hint, contains('Double tap'));
    });
  });
}
