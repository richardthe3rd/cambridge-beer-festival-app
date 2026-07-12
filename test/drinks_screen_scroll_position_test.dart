// Regression test for issue #470: navigating from the drinks list to a
// drink detail screen (and back) used to reset the drinks list's scroll
// position, because navigateToRoute() used context.go() on web, which
// disposes DrinksScreen rather than covering it.
//
// The fix (see lib/router.dart's _buildRouter() and
// lib/utils/navigation_helpers.dart's navigateToRoute()) makes
// navigateToRoute() always context.push(), and enables go_router's
// GoRouter.optionURLReflectsImperativeAPIs flag so push() still updates the
// browser URL. push() keeps DrinksScreen mounted (offstage) underneath the
// pushed route instead of disposing it, so its ScrollPosition survives
// automatically.
//
// This test exercises the real production appRouter (not a stub route
// table) so it proves the fix end-to-end through the actual ShellRoute
// nesting that caused the original bug.
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/router.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

const String testFestivalId = 'cbf2025';

/// Generates enough drinks to scroll well past a single screen.
List<Drink> _createManyDrinks(int count) {
  final producer = Producer.fromJson({
    'id': 'brewery-1',
    'name': 'Test Brewery',
    'location': 'Cambridge',
    'products': [],
  });

  return List.generate(count, (i) {
    final product = Product.fromJson({
      'id': 'drink-$i',
      'name': 'Test Drink $i',
      'category': 'beer',
      'style': 'IPA',
      'dispense': 'cask',
      'abv': '5.0',
    });
    return Drink(
      product: product,
      producer: producer,
      festivalId: testFestivalId,
    );
  });
}

void main() {
  group('DrinksScreen scroll position survives push navigation', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;
    late List<Drink> drinks;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      drinks = _createManyDrinks(40);

      const testFestival = Festival(
        id: testFestivalId,
        name: 'Cambridge Beer Festival 2025',
        dataBaseUrl: 'https://test.example.com/cbf2025',
      );
      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [testFestival],
          defaultFestivalId: testFestivalId,
          baseUrl: 'https://example.com',
          version: '1.0.0',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => drinks);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
      await provider.loadDrinks();
    });

    tearDown(() {
      provider.dispose();
    });

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      appRouter.go('/$testFestivalId');
      await tester.pumpAndSettle();
    }

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
        await pumpApp(tester);

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
        appRouter.pop();
        await tester.pumpAndSettle();

        // The drinks list is showing again...
        expect(find.byType(DrinksScreen), findsOneWidget);
        // ...and its scroll position was never reset, because DrinksScreen
        // was pushed-under (offstage), not disposed and recreated.
        expect(drinksListScrollPixels(tester), scrolledPosition);
      },
    );

    testWidgets('a freshly-loaded drinks list starts at scroll offset zero', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(drinksListScrollPixels(tester), 0);
    });
  });
}
