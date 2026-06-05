import 'package:cambridge_beer_festival/widgets/drinks_filter_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  /// Our explicit Semantics wrapper carries [label]; FilledButton adds its own
  /// nested Semantics, so match on the exact label we set.
  Semantics semanticsWithLabel(WidgetTester tester, String label) {
    return tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.label == label);
  }

  group('FilterButton', () {
    testWidgets('shows label and fires onPressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          FilterButton(
            label: 'Category',
            icon: Icons.filter_list,
            isActive: false,
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Category'), findsOneWidget);
      await tester.tap(find.byType(FilterButton));
      expect(tapped, isTrue);
    });

    testWidgets(
      'uses semanticLabel when provided and signals clear when active',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            FilterButton(
              label: 'IPA',
              semanticLabel: 'Filter by style: IPA',
              icon: Icons.style,
              isActive: true,
              onPressed: () {},
            ),
          ),
        );

        final semantics = semanticsWithLabel(tester, 'Filter by style: IPA');
        expect(
          semantics.properties.hint,
          'Double tap to change or clear this filter',
        );
        expect(semantics.properties.button, isTrue);
        // Active state surfaces a clear (x) icon.
        expect(find.byIcon(Icons.close), findsOneWidget);
      },
    );

    testWidgets('inactive button hints at selecting a filter', (tester) async {
      await tester.pumpWidget(
        wrap(
          FilterButton(
            label: 'Category',
            icon: Icons.filter_list,
            isActive: false,
            onPressed: () {},
          ),
        ),
      );

      expect(
        semanticsWithLabel(tester, 'Category').properties.hint,
        'Double tap to select filter',
      );
    });
  });

  group('SearchButton', () {
    testWidgets('labels and icon reflect open/closed state', (tester) async {
      await tester.pumpWidget(
        wrap(SearchButton(isActive: false, onPressed: () {})),
      );
      expect(
        () => semanticsWithLabel(tester, 'Search drinks'),
        returnsNormally,
      );
      expect(find.byIcon(Icons.search), findsOneWidget);

      await tester.pumpWidget(
        wrap(SearchButton(isActive: true, onPressed: () {})),
      );
      expect(() => semanticsWithLabel(tester, 'Close search'), returnsNormally);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('highlights when a query is active but the bar is closed', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(SearchButton(isActive: false, hasQuery: true, onPressed: () {})),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final background = button.style!.backgroundColor!.resolve({});
      expect(background, isNotNull);
    });
  });

  group('VisibilityFilterButton', () {
    testWidgets('hides count when no filters are active', (tester) async {
      await tester.pumpWidget(
        wrap(VisibilityFilterButton(activeCount: 0, onPressed: () {})),
      );
      expect(() => semanticsWithLabel(tester, 'View filters'), returnsNormally);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows active count in label and badge', (tester) async {
      await tester.pumpWidget(
        wrap(VisibilityFilterButton(activeCount: 3, onPressed: () {})),
      );
      expect(
        () => semanticsWithLabel(tester, 'View filters (3)'),
        returnsNormally,
      );
      expect(find.text('3'), findsOneWidget);
    });
  });
}
