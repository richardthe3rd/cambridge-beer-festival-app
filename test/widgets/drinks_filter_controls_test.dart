import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/widgets/drinks_filter_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void _noop() {}

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  /// Same as [wrap] but with the real app theme, so text is laid out in the
  /// bundled Nunito Sans at the real label scale. Any width assertion has to
  /// use this — a bare MaterialApp falls back to the test font, which is
  /// roughly twice as wide and makes a width budget meaningless.
  Widget wrapThemed(Widget child) => MaterialApp(
    theme: buildAppTheme(Brightness.light),
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

    testWidgets('drops the leading glyph once a filter is applied', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          FilterButton(
            label: 'Beer',
            icon: Icons.filter_list,
            isActive: false,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.pumpWidget(
        wrap(
          FilterButton(
            label: 'Beer',
            icon: Icons.filter_list,
            isActive: true,
            onPressed: () {},
          ),
        ),
      );
      // The clear (x) already identifies the button as active, so the leading
      // glyph gives up its 18px (plus an 8px gap) to the label — the width
      // that made the label vanish entirely at phone sizes (#579).
      expect(find.byIcon(Icons.filter_list), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('active label is not ellipsized at a phone-width share', (
      tester,
    ) async {
      // 109px is what the category button gets on a 400px-wide screen once
      // the bottom control row has paid for its two square buttons, its
      // padding and its gaps (see _BottomControls in drinks_screen.dart).
      // Before #579 the label was the only Flexible child, so it absorbed the
      // entire shortfall and rendered as nothing at all.
      await tester.pumpWidget(
        wrapThemed(
          const SizedBox(
            width: 109,
            child: FilterButton(
              label: '2 categories',
              icon: Icons.filter_list,
              isActive: true,
              onPressed: _noop,
            ),
          ),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('2 categories'),
      );
      // An ellipsized paragraph is laid out at the constraint rather than at
      // the width the string actually needs — asserting on find.text alone
      // would pass even with the label clipped to zero.
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)),
        reason: 'The label must render whole, not ellipsize to nothing.',
      );
    });

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
