// Regression test for issue #470: navigating from the drinks list to a
// drink detail screen (and back) used to reset the drinks list's scroll
// position, because navigateToRoute() used context.go() on web, which
// disposes DrinksScreen rather than covering it.
//
// The fix (see lib/router.dart's buildAppRouter() and
// lib/utils/navigation_helpers.dart's navigateToRoute()) makes
// navigateToRoute() always context.push(), and enables go_router's
// GoRouter.optionURLReflectsImperativeAPIs flag (set once in main()) so
// push() still updates the browser URL. push() keeps DrinksScreen mounted
// (offstage) underneath the pushed route instead of disposing it, so its
// ScrollPosition survives automatically.
//
// This test exercises the real production route table (not a stub) so it
// proves the fix end-to-end through the actual ShellRoute nesting that caused
// the original bug.
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_harness.dart';

void main() {
  group('DrinksScreen scroll position survives push navigation', () {
    late AppHarness harness;

    setUp(() async {
      harness = await AppHarness.create();
    });

    tearDown(() {
      harness.dispose();
    });

    double drinksListScrollPixels(WidgetTester tester) {
      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      return tester.state<ScrollableState>(scrollable.first).position.pixels;
    }

    /// Drags the drinks list down in small steps until [target] is built
    /// (and therefore hit-testable). A single large fling can leave the
    /// widget only within the sliver's cacheExtent — present in the tree
    /// but off-screen and un-tappable — so small steps that stop as soon as
    /// the target appears are used instead.
    ///
    /// WidgetTester.scrollUntilVisible() was tried here and rejected: it
    /// requires its `scrollable` finder to resolve to exactly one
    /// `Scrollable`, but this screen's subtree matches more than one (see
    /// `drinksListScrollPixels()`'s `.first` above), so it throws
    /// "Bad state: Too many elements" — confirmed by running it.
    Future<void> scrollDownUntilVisible(
      WidgetTester tester,
      Finder target,
    ) async {
      for (var i = 0; i < 40; i++) {
        if (target.evaluate().isNotEmpty) return;
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();
      }
      fail('Target widget never became visible after scrolling');
    }

    testWidgets(
      'scroll position is preserved after navigating to drink detail and back',
      (tester) async {
        await harness.pump(tester);

        // Sanity check: starts at the top.
        expect(drinksListScrollPixels(tester), 0);

        // Scroll the drinks list until a drink card well past the first
        // screen (SliverList only builds items near the viewport, so a
        // blind fling + "tap the first built DrinkCard" can hit a card
        // that's in the tree via cacheExtent but not actually on-screen —
        // scrolling in small steps until the target appears guarantees
        // it's actually hit-testable before we tap it).
        const targetKey = ValueKey('drink-30');
        await scrollDownUntilVisible(tester, find.byKey(targetKey));
        await tester.pumpAndSettle();

        final scrolledPosition = drinksListScrollPixels(tester);
        expect(
          scrolledPosition,
          greaterThan(0),
          reason: 'Test setup check: the list must actually have scrolled',
        );

        // Tap the now-visible drink card — this exercises
        // navigateToRoute() -> context.push().
        await tester.tap(find.byKey(targetKey));
        await tester.pumpAndSettle();

        // The drink detail screen is now showing.
        expect(find.byType(DrinkDetailScreen), findsOneWidget);

        // Pop back to the drinks list.
        harness.router.pop();
        await tester.pumpAndSettle();

        // The drinks list is showing again...
        expect(find.byType(DrinksScreen), findsOneWidget);
        // ...and its scroll position was never reset, because DrinksScreen
        // was pushed-under (offstage), not disposed and recreated.
        expect(drinksListScrollPixels(tester), scrolledPosition);
      },
    );
  });
}
