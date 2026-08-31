// Journey coverage for category filtering — issue #314, flow 2.
//
// search_and_filter_test.dart covers the rest of that flow (searching, and
// the style sheet); the category sheet was the one filter no test drove from
// the drinks list. The pieces are covered on their own —
// drink_filter_controller_test.dart pins the selection semantics and the
// facet-scoping rule, and drink_filter_sheets_test.dart taps the sheet's
// checkboxes — but both stop at `provider.selectedCategories`. The sheet
// tests mount CategoryFilterSheet over a launcher host with no drinks list
// behind it, so none of them can assert the thing the user is actually
// after: that a drink card leaves the list.
//
// So, like its sibling, this file asserts on the drinks on screen, plus the
// filter button's own announcement — the only place the active category is
// visible once the sheet is dismissed.
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Long enough to clear DrinksScreen's 300ms search debounce
/// (drinks_screen.dart:28).
const Duration _pastSearchDebounce = Duration(milliseconds: 350);

void main() {
  group('Category filter journey (#314)', () {
    late AppHarness harness;

    setUp(() async {
      harness = await AppHarness.create(
        drinks: [
          createDrink(id: 'alpha', name: 'Alpha Ale', style: 'IPA'),
          createDrink(id: 'beta', name: 'Beta Bitter', style: 'Bitter'),
          createDrink(
            id: 'gamma',
            name: 'Gamma Cider',
            category: 'cider',
            style: 'Dry',
          ),
          createDrink(
            id: 'delta',
            name: 'Delta Perry',
            category: 'perry',
            style: 'Medium',
          ),
        ],
      );
    });

    tearDown(() {
      harness.dispose();
    });

    /// Runs [body] with semantics switched on.
    ///
    /// try/finally, not addTearDown: addTearDown runs after the framework's
    /// end-of-test SemanticsHandle check, so a leaked handle reports as the
    /// failure and masks the real one (the finding recorded in
    /// favourites_test.dart).
    Future<void> withSemantics(
      WidgetTester tester,
      Future<void> Function() body,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await body();
      } finally {
        semantics.dispose();
      }
    }

    /// The category FilterButton, found the way a screen reader would.
    ///
    /// Matched on the prefix because the button relabels itself as the filter
    /// is applied ('Filter by category' -> 'Filter by category: Cider'), and
    /// the same journey taps it in both states. Its visible label collides
    /// with the category chip every DrinkCard renders — `find.text('Cider')`
    /// matches the card too — so the semantic label is also the only
    /// unambiguous handle on it.
    Finder categoryButton() =>
        find.bySemanticsLabel(RegExp('^Filter by category'));

    /// What a screen reader announces for that button.
    String categoryButtonLabel(WidgetTester tester) =>
        tester.getSemantics(categoryButton()).label;

    Future<void> openCategorySheet(WidgetTester tester) async {
      await tester.tap(categoryButton());
      await tester.pumpAndSettle();
      expect(find.text('Filter by Category'), findsOneWidget);
    }

    /// Dismisses a modal sheet by tapping its scrim. Top-left, matching
    /// search_and_filter_test — a centre-x tap assumes the default 800px-wide
    /// surface and lands inside the sheet on a narrower one.
    Future<void> dismissSheet(WidgetTester tester) async {
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }

    Future<void> toggleCategory(WidgetTester tester, String category) async {
      await tester.tap(find.byKey(ValueKey('category-$category')));
      await tester.pumpAndSettle();
    }

    void expectListShows(List<String> names) {
      for (final name in [
        'Alpha Ale',
        'Beta Bitter',
        'Gamma Cider',
        'Delta Perry',
      ]) {
        expect(
          find.text(name),
          names.contains(name) ? findsOneWidget : findsNothing,
          reason: names.contains(name)
              ? '$name should be listed'
              : '$name should have been filtered out of the list',
        );
      }
    }

    testWidgets('a category filter narrows the list to that category', (
      tester,
    ) async {
      await withSemantics(tester, () async {
        await harness.pump(tester);
        expectListShows([
          'Alpha Ale',
          'Beta Bitter',
          'Gamma Cider',
          'Delta Perry',
        ]);
        expect(categoryButtonLabel(tester), 'Filter by category');

        await openCategorySheet(tester);
        // The counts are the whole catalogue's, before any category applies.
        expect(find.text('All (4)'), findsOneWidget);
        expect(find.text('Beer (2)'), findsOneWidget);
        expect(find.text('Cider (1)'), findsOneWidget);

        await toggleCategory(tester, 'cider');
        await dismissSheet(tester);

        expectListShows(['Gamma Cider']);
        // ...and the button now says which filter is on, so it can be found
        // and cleared again.
        expect(categoryButtonLabel(tester), 'Filter by category: Cider');
      });
    });

    testWidgets('a second category brings its drinks back into the list', (
      tester,
    ) async {
      await withSemantics(tester, () async {
        await harness.pump(tester);

        await openCategorySheet(tester);
        await toggleCategory(tester, 'cider');
        await toggleCategory(tester, 'perry');
        await dismissSheet(tester);

        expectListShows(['Gamma Cider', 'Delta Perry']);
        // Both categories are announced, formatted and sorted — the
        // deterministic order drinks_screen.dart promises for a Set that has
        // none.
        expect(categoryButtonLabel(tester), 'Filter by category: Cider, Perry');
        // The visible label counts them rather than listing them, so it still
        // fits the pill.
        expect(
          find.descendant(
            of: find.byType(FilterButton),
            matching: find.text('2 categories'),
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('All restores every category to the list', (tester) async {
      await withSemantics(tester, () async {
        await harness.pump(tester);

        await openCategorySheet(tester);
        await toggleCategory(tester, 'cider');
        await dismissSheet(tester);
        expectListShows(['Gamma Cider']);

        await openCategorySheet(tester);
        await toggleCategory(tester, 'all');
        await dismissSheet(tester);

        expectListShows([
          'Alpha Ale',
          'Beta Bitter',
          'Gamma Cider',
          'Delta Perry',
        ]);
        expect(categoryButtonLabel(tester), 'Filter by category');
      });
    });

    testWidgets('a category filter scopes the style sheet, not itself', (
      tester,
    ) async {
      await withSemantics(tester, () async {
        await harness.pump(tester);

        await openCategorySheet(tester);
        await toggleCategory(tester, 'cider');
        await dismissSheet(tester);

        // The style sheet now offers only the styles still reachable — the
        // user cannot pick a beer style that would empty the list.
        await tester.tap(find.text('Style'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(CheckboxListTile, 'Dry (1)'),
          findsOneWidget,
        );
        for (final unreachable in ['IPA', 'Bitter', 'Medium']) {
          expect(
            find.descendant(
              of: find.byType(CheckboxListTile),
              matching: find.textContaining(unreachable),
            ),
            findsNothing,
            reason:
                '$unreachable belongs to a filtered-out category and should '
                'not be offered in the style sheet',
          );
        }
        await dismissSheet(tester);

        // The category sheet, though, still lists every category — a facet
        // must not narrow itself, or Beer would vanish from the very control
        // the user needs to get back to it.
        await openCategorySheet(tester);
        expect(find.text('Beer (2)'), findsOneWidget);
        expect(find.text('Perry (1)'), findsOneWidget);
      });
    });

    testWidgets('a category filter and a search narrow the list together', (
      tester,
    ) async {
      await withSemantics(tester, () async {
        await harness.pump(tester);

        await openCategorySheet(tester);
        await toggleCategory(tester, 'cider');
        await dismissSheet(tester);
        expectListShows(['Gamma Cider']);

        await tester.tap(find.bySemanticsLabel('Search drinks'));
        await tester.pumpAndSettle();

        // A beer that matches the query by name is still filtered out: the
        // two narrow together, rather than the search replacing the category.
        await tester.enterText(find.byType(TextField).first, 'Alpha');
        await tester.pump(_pastSearchDebounce);
        await tester.pumpAndSettle();

        expectListShows([]);
        expect(find.text('No drinks found'), findsOneWidget);

        // Clearing the search returns to the cider drink, not to all four —
        // the category filter outlived the search.
        await tester.tap(find.bySemanticsLabel('Clear search'));
        await tester.pump(_pastSearchDebounce);
        await tester.pumpAndSettle();

        expectListShows(['Gamma Cider']);
        expect(categoryButtonLabel(tester), 'Filter by category: Cider');
      });
    });
  });
}
