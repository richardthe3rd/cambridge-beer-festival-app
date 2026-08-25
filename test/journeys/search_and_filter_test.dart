// Journey coverage for search and filtering — issue #314, flow 2.
//
// The pieces are well covered on their own: drink_filter_service_test.dart
// pins the filter semantics, drinks_screen_style_filter_test.dart drives the
// style sheet's checkboxes and button counts, and drinks_screen_debounce_test
// .dart covers the search debounce. What none of them assert is the thing the
// user actually cares about — that the list on screen narrows. Searching
// `findsNothing` in drinks_screen_style_filter_test.dart turns up assertions
// about button labels and chips, never about a drink card leaving the list.
//
// So this file deliberately asserts only on drink names in the list.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Long enough to clear DrinksScreen's 300ms search debounce
/// (drinks_screen.dart:28).
const Duration _pastSearchDebounce = Duration(milliseconds: 350);

void main() {
  group('Search and filter journey (#314)', () {
    late AppHarness harness;

    setUp(() async {
      harness = await AppHarness.create(
        drinks: [
          createDrink(id: 'alpha', name: 'Alpha Ale', style: 'IPA'),
          createDrink(id: 'beta', name: 'Beta Bitter', style: 'Bitter'),
          createDrink(id: 'gamma', name: 'Gamma Stout', style: 'Stout'),
        ],
      );
    });

    tearDown(() {
      harness.dispose();
    });

    // find.bySemanticsLabel needs semantics switched on. It happens to be on
    // by default under `flutter test` here, but every test that relies on it
    // takes its own handle rather than depending on that — the repo pattern
    // (drink_detail_screen_test.dart, drinks_screen_style_filter_test.dart).
    Future<void> openSearch(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Search drinks'));
      await tester.pumpAndSettle();
    }

    Future<void> search(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField).first, query);
      await tester.pump(_pastSearchDebounce);
      await tester.pumpAndSettle();
    }

    void expectListShows(List<String> names) {
      for (final name in ['Alpha Ale', 'Beta Bitter', 'Gamma Stout']) {
        expect(
          find.text(name),
          names.contains(name) ? findsOneWidget : findsNothing,
          reason: names.contains(name)
              ? '$name should be listed'
              : '$name should have been filtered out of the list',
        );
      }
    }

    testWidgets('searching narrows the list to matching drinks', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await harness.pump(tester);
        expectListShows(['Alpha Ale', 'Beta Bitter', 'Gamma Stout']);

        await openSearch(tester);
        await search(tester, 'stout');

        expectListShows(['Gamma Stout']);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('clearing the search restores every drink', (tester) async {
      await harness.pump(tester);
      final semantics = tester.ensureSemantics();
      try {
        await openSearch(tester);
        await search(tester, 'stout');
        expectListShows(['Gamma Stout']);

        await tester.tap(find.bySemanticsLabel('Clear search'));
        await tester.pump(_pastSearchDebounce);
        await tester.pumpAndSettle();

        expectListShows(['Alpha Ale', 'Beta Bitter', 'Gamma Stout']);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('a search matching nothing shows the empty state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await harness.pump(tester);
        await openSearch(tester);
        await search(tester, 'nothing matches this');

        expectListShows([]);
        expect(find.text('No drinks found'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('a style filter narrows the list to that style', (
      tester,
    ) async {
      await harness.pump(tester);

      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Stout (1)'));
      await tester.pumpAndSettle();

      // Dismiss the modal sheet by tapping its scrim. Top-left, matching
      // drinks_screen_style_filter_test — a centre-x tap assumes the default
      // 800px-wide surface and lands inside the sheet on a narrower one.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expectListShows(['Gamma Stout']);
    });
  });
}
