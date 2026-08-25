// Journey coverage for the favourites ("Want to Try") flow — issue #314,
// flow 3.
//
// This flow had no interaction coverage at all before this file:
// `grep 'tap(' test/ | grep -i favourit` returned nothing. Every existing
// test toggles want-to-try by calling BeerProvider directly, which skips the
// two places the flow actually breaks — the control the user presses, and the
// screen that has to list the result.
//
// Those two halves also read personal state through different paths:
// BeerProvider.toggleFavorite() writes via DrinkRepository.toggleFavorite(),
// but MyFestivalScreen renders provider.myFestivalEntries, which re-reads via
// DrinkRepository.getPersonalEntries() (beer_provider.dart:206) rather than
// caching the write. A test that stubs only the writer passes while My
// Festival stays permanently empty, so the harness backs both with one store.
//
// Note the drink card itself has no favourite control: #413 removed the heart
// and left DrinkCard.onFavoriteTap vestigial. The only way in is the
// YourTakeCard pill on the drink detail screen, so that is where this journey
// starts.
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  group('Want to Try journey (#314)', () {
    late AppHarness harness;

    setUp(() async {
      harness = await AppHarness.create();
    });

    tearDown(() {
      harness.dispose();
    });

    /// The YourTakeCard pill, scoped so it can't collide with the "Want to
    /// Try" section header on MyFestivalScreen when both are mounted.
    Finder wantToTryPill() => find.descendant(
      of: find.byType(YourTakeCard),
      matching: find.widgetWithText(InkWell, 'Want to Try'),
    );

    /// What a screen reader announces for the pill.
    String pillSemanticsLabel(WidgetTester tester) =>
        tester.getSemantics(wantToTryPill()).label;

    /// Opens the drink detail screen for [drinkId] from the drinks list.
    Future<void> openDrink(WidgetTester tester, String drinkId) async {
      await tester.tap(find.byKey(ValueKey(drinkId)));
      await tester.pumpAndSettle();
      expect(find.byType(DrinkDetailScreen), findsOneWidget);
    }

    /// Switches to My Festival the way a user does — the bottom nav tab.
    Future<void> openMyFestival(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('favorites_tab')));
      await tester.pumpAndSettle();
      expect(find.byType(MyFestivalScreen), findsOneWidget);
    }

    testWidgets(
      'a drink marked want-to-try appears on My Festival, and unmarking it '
      'removes it again',
      (tester) async {
        // try/finally, not addTearDown: addTearDown runs after the
        // framework's end-of-test SemanticsHandle check, so a leaked handle
        // reports as the failure and masks the real one.
        final semanticsHandle = tester.ensureSemantics();
        try {
          await harness.pump(tester);

          // My Festival starts empty.
          await openMyFestival(tester);
          expect(find.text('0 in My Festival'), findsOneWidget);
          expect(find.text('Nothing in My Festival yet'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('want-to-try-drink-1')),
            findsNothing,
          );

          // Back to the list, then into a drink.
          await tester.tap(find.byKey(const Key('drinks_tab')));
          await tester.pumpAndSettle();
          await openDrink(tester, 'drink-1');

          // The pill starts un-toggled, and says so to a screen reader.
          //
          // startsWith, not equals: this Semantics wrapper doesn't set
          // excludeSemantics, so the visible 'Want to Try' text merges in and
          // the announced label is "Add ... to want to try\nWant to Try".
          expect(
            pillSemanticsLabel(tester),
            startsWith('Add Test Drink 1 to want to try'),
          );
          expect(
            find.descendant(
              of: find.byType(YourTakeCard),
              matching: find.byIcon(Icons.bookmark_border),
            ),
            findsOneWidget,
          );

          await tester.tap(wantToTryPill());
          await tester.pumpAndSettle();

          // It flips in place — icon and semantics both.
          expect(
            pillSemanticsLabel(tester),
            startsWith('Remove Test Drink 1 from want to try'),
          );
          expect(
            find.descendant(
              of: find.byType(YourTakeCard),
              matching: find.byIcon(Icons.bookmark),
            ),
            findsOneWidget,
          );

          // Back out to the list and across to My Festival: the drink is listed.
          harness.router.pop();
          await tester.pumpAndSettle();
          await openMyFestival(tester);

          expect(
            find.byKey(const ValueKey('want-to-try-drink-1')),
            findsOneWidget,
          );
          expect(find.text('Test Drink 1'), findsOneWidget);
          expect(find.text('1 in My Festival'), findsOneWidget);
          expect(find.text('Nothing in My Festival yet'), findsNothing);

          // Tapping the row goes back into the same drink...
          await tester.tap(find.byKey(const ValueKey('want-to-try-drink-1')));
          await tester.pumpAndSettle();
          expect(find.byType(DrinkDetailScreen), findsOneWidget);
          expect(
            pillSemanticsLabel(tester),
            startsWith('Remove Test Drink 1 from want to try'),
          );

          // ...where unmarking it takes it off the list again.
          await tester.tap(wantToTryPill());
          await tester.pumpAndSettle();
          harness.router.pop();
          await tester.pumpAndSettle();

          expect(find.byType(MyFestivalScreen), findsOneWidget);
          expect(
            find.byKey(const ValueKey('want-to-try-drink-1')),
            findsNothing,
          );
          expect(find.text('Test Drink 1'), findsNothing);
          expect(find.text('0 in My Festival'), findsOneWidget);
          expect(find.text('Nothing in My Festival yet'), findsOneWidget);
        } finally {
          semanticsHandle.dispose();
        }
      },
    );

    testWidgets('several drinks accumulate on My Festival', (tester) async {
      await harness.pump(tester);

      for (final drinkId in ['drink-0', 'drink-1']) {
        await openDrink(tester, drinkId);
        await tester.tap(wantToTryPill());
        await tester.pumpAndSettle();
        harness.router.pop();
        await tester.pumpAndSettle();
      }

      await openMyFestival(tester);

      expect(find.byKey(const ValueKey('want-to-try-drink-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('want-to-try-drink-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('want-to-try-drink-2')), findsNothing);
      expect(find.text('2 in My Festival'), findsOneWidget);
    });
  });
}
