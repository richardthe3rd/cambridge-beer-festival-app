// Journey coverage for deep-link cold start — issue #314, flow 5.
//
// router_test.dart covers route *resolution* thoroughly, but it does so by
// calling appRouter.go() on an already-mounted app: a warm start, with the
// drinks list sitting underneath. A real deep link — a shared drink URL opened
// from a message, the case ADR 0004 designed these URLs for — resolves before
// the first frame and has nothing beneath it.
//
// That difference is user-visible: there is no back destination. It is also
// where a deep link can fail in a way a warm navigation cannot, because the
// screen has to render from a provider that is still loading when the route is
// resolved.
//
// These tests therefore assert what is on screen after a cold launch, not just
// which route matched.
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  group('Deep-link cold start journey (#314)', () {
    late AppHarness harness;

    setUp(() async {
      harness = await AppHarness.create(
        drinks: [
          createDrink(
            id: 'alpha',
            name: 'Alpha Ale',
            style: 'IPA',
            breweryName: 'Cambridge Brewery',
          ),
          createDrink(id: 'beta', name: 'Beta Bitter', style: 'Bitter'),
        ],
      );
    });

    tearDown(() {
      harness.dispose();
    });

    String currentLocation() =>
        harness.router.routerDelegate.currentConfiguration.uri.toString();

    testWidgets('launching on a drink URL opens that drink, with no way back', (
      tester,
    ) async {
      await harness.pumpColdAt(tester, '/cbf2025/drink/beer/alpha');

      // The right drink is actually rendered — not merely the right route.
      expect(find.byType(DrinkDetailScreen), findsOneWidget);
      expect(find.text('Alpha Ale'), findsWidgets);
      expect(find.text('Cambridge Brewery'), findsWidgets);
      expect(currentLocation(), '/cbf2025/drink/beer/alpha');

      // Nothing was navigated through to get here, so the drinks list was
      // never built — not even offstage beneath the detail screen.
      expect(
        find.byType(DrinksScreen, skipOffstage: false),
        findsNothing,
        reason: 'A cold launch must not synthesise a list underneath',
      );
      expect(
        harness.router.routerDelegate.canPop(),
        isFalse,
        reason: 'A deep link has no back destination',
      );
    });

    testWidgets('launching on My Festival opens it with the nav bar', (
      tester,
    ) async {
      await harness.pumpColdAt(tester, '/cbf2025/favorites');

      expect(find.byType(MyFestivalScreen), findsOneWidget);
      // The shell route supplies the bottom nav, so a cold launch here is a
      // tab the user can navigate out of, unlike the detail route above.
      expect(find.byKey(const Key('drinks_tab')), findsOneWidget);
      expect(currentLocation(), '/cbf2025/favorites');
    });

    testWidgets('a stale festival in the URL still opens the drink', (
      tester,
    ) async {
      await harness.pumpColdAt(tester, '/not-a-festival/drink/beer/alpha');

      // The redirect rewrites only the festival segment and keeps the rest of
      // the path, so last year's shared link opens this year's listing for the
      // same drink rather than stranding the user on an error screen.
      expect(currentLocation(), '/cbf2025/drink/beer/alpha');
      expect(find.byType(DrinkDetailScreen), findsOneWidget);
      expect(find.text('Alpha Ale'), findsWidgets);
    });
  });
}
