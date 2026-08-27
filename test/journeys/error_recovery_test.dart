// Journey coverage for offline / error recovery — issue #314, flow 6.
//
// drinks_screen_refresh_status_test.dart already renders three of the four
// loading/error signals, but each one statically: it builds a provider that is
// already in the failed state, mounts DrinksScreen, and asserts what is drawn.
// What no test drove is the *transition* — the thing a user at a festival with
// patchy signal actually experiences:
//
//   failure -> what's on screen while failed -> retry -> recovered
//
// Both halves of that matter and they differ. A cold failure blocks with a
// full-screen error and no data; a failed background refresh must keep the
// cached drinks on screen behind a dismissible notice. AGENTS.md pins those
// four signals as mutually exclusive, so the recovery has to clear the old one
// as well as show the new state.
import 'dart:async';

import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  group('Error recovery journey (#314)', () {
    testWidgets('a cold failure blocks, and Retry recovers into the list', (
      tester,
    ) async {
      final harness = await AppHarness.create(
        drinks: [createDrink(id: 'alpha', name: 'Alpha Ale')],
        drinksError: BeerApiException('boom', 500),
      );
      addTearDown(harness.dispose);
      await harness.pump(tester);

      // Nothing loaded, so this is the blocking signal, not the notice.
      expect(find.text('Error loading drinks'), findsOneWidget);
      expect(
        find.text('Server error. Please try again later.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
      expect(find.text('Alpha Ale'), findsNothing);
      // The four signals are mutually exclusive — no cached-data banner here.
      expect(find.textContaining('saved data'), findsNothing);

      // The network comes back, and the user taps Retry.
      harness.recoverDrinks();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pumpAndSettle();

      // Recovered: the drink is listed and the error view is gone.
      expect(find.text('Alpha Ale'), findsOneWidget);
      expect(find.text('Error loading drinks'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsNothing);
    });

    testWidgets(
      'a failed refresh keeps the cached list on screen, and a later refresh '
      'replaces it with fresh data',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final harness = await AppHarness.create(
            drinks: [createDrink(id: 'alpha', name: 'Alpha Ale')],
          );
          addTearDown(harness.dispose);
          await harness.pump(tester);
          expect(find.text('Alpha Ale'), findsOneWidget);

          // Signal goes away mid-festival; the user pulls to refresh.
          harness.failDrinks(TimeoutException('offline'));
          await pullToRefresh(tester);

          // The cached drink survives — this is the notice, not the blocking
          // error view.
          expect(find.textContaining('saved data'), findsOneWidget);
          expect(find.text('Alpha Ale'), findsOneWidget);
          expect(find.text('Error loading drinks'), findsNothing);

          // Signal returns, and the feed has moved on since the cache.
          harness.recoverDrinks(
            drinks: [createDrink(id: 'beta', name: 'Beta Bitter')],
          );
          await pullToRefresh(tester);

          // The notice clears and the stale drink is genuinely replaced.
          expect(find.textContaining('saved data'), findsNothing);
          expect(find.text('Beta Bitter'), findsOneWidget);
          expect(find.text('Alpha Ale'), findsNothing);
        } finally {
          semantics.dispose();
        }
      },
    );
  });
}

/// Drags the drinks list down far enough to trip its RefreshIndicator
/// (drinks_screen.dart wires `onRefresh: provider.loadDrinks`).
Future<void> pullToRefresh(WidgetTester tester) async {
  await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
  await tester.pumpAndSettle();
}
