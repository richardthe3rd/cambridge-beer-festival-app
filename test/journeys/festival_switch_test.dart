// Journey coverage for switching festivals — issue #314, flow 4.
//
// Component coverage for the pieces exists (festival_flash_guard_test.dart for
// the no-flash guard, festival_menu_sheets_test.dart for the sheet itself),
// but nothing drove the whole switch: open the menu, pick another festival,
// and check the drinks list actually swapped over.
//
// #314 also asserts the URL changes on switch. Archived todo C3 says it does
// not — that note predates the current selector, which calls
// `router.go(targetPath)` after `provider.setFestival()`
// (festival_menu_sheets.dart:216-218). The URL assertion below is what settles
// it; if it ever regresses, C3 is real again.
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const Festival festival2025 = defaultTestFestival;
const Festival festival2024 = Festival(
  id: 'cbf2024',
  name: 'Cambridge Beer Festival 2024',
  dataBaseUrl: 'https://test.example.com/cbf2024',
);

void main() {
  group('Festival switch journey (#314)', () {
    late AppHarness harness;

    setUp(() async {
      harness = await AppHarness.create(
        festivals: const [festival2025, festival2024],
        drinksByFestival: {
          festival2025.id: createSampleDrinks(
            4,
            festivalId: festival2025.id,
            breweryName: 'Cambridge Brewery',
          ),
          festival2024.id: createSampleDrinks(
            4,
            festivalId: festival2024.id,
            idPrefix: 'vintage',
            namePrefix: 'Vintage Ale',
            breweryName: 'Vintage Brewery',
          ),
        },
      );
    });

    tearDown(() {
      harness.dispose();
    });

    String currentLocation() =>
        harness.router.routerDelegate.currentConfiguration.uri.toString();

    /// Opens the festival browser the way a user does — overflow menu, then
    /// the Browse Festivals item.
    Future<void> openFestivalBrowser(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse Festivals'));
      await tester.pumpAndSettle();
    }

    testWidgets('picking another festival swaps the drinks list and the URL', (
      tester,
    ) async {
      await harness.pump(tester);

      // Opens on 2025: its drinks are listed, 2024's are not.
      expect(find.text('Test Drink 0'), findsOneWidget);
      expect(find.text('Vintage Ale 0'), findsNothing);
      expect(currentLocation(), '/${festival2025.id}');

      await openFestivalBrowser(tester);
      await tester.tap(find.widgetWithText(FestivalCard, festival2024.name));
      await tester.pumpAndSettle();

      // The list swapped over completely — the old festival's drinks are gone,
      // not merely pushed down.
      expect(find.text('Vintage Ale 0'), findsOneWidget);
      expect(find.text('Test Drink 0'), findsNothing);

      // ...and the URL followed, so the new festival is shareable and
      // reloadable (the half of flow 4 archived todo C3 said was missing).
      expect(currentLocation(), '/${festival2024.id}');
    });

    testWidgets('switching back restores the first festival', (tester) async {
      await harness.pump(tester);

      await openFestivalBrowser(tester);
      await tester.tap(find.widgetWithText(FestivalCard, festival2024.name));
      await tester.pumpAndSettle();
      expect(find.text('Vintage Ale 0'), findsOneWidget);

      await openFestivalBrowser(tester);
      await tester.tap(find.widgetWithText(FestivalCard, festival2025.name));
      await tester.pumpAndSettle();

      expect(find.text('Test Drink 0'), findsOneWidget);
      expect(find.text('Vintage Ale 0'), findsNothing);
      expect(currentLocation(), '/${festival2025.id}');
    });
  });
}
