// Regression/proof test for issue #523: DrinksScreen used to
// context.watch<BeerProvider>() as a whole, so a change to any provider
// field — including one DrinksScreen never renders, like themeMode —
// rebuilt the entire screen and, with it, every DrinkCard in the visible
// list. Narrowing to per-concern context.select calls means an unrelated
// notifyListeners() no longer touches DrinksScreen.build() at all.
//
// DrinkCard.debugBuildCount (assert-gated, lib/widgets/drink_card.dart) is
// the direct proof: it counts real calls to DrinkCard.build(), not a proxy
// state variable.
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('DrinksScreen narrowed rebuilds (#523)', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    final testDrinks = [
      Drink(
        product: const Product(
          id: 'drink1',
          name: 'Alpha IPA',
          abv: 5.5,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        ),
        producer: const Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'cbf2025',
      ),
      Drink(
        product: const Product(
          id: 'drink2',
          name: 'Beta Bitter',
          abv: 4.2,
          category: 'beer',
          dispense: 'cask',
          style: 'Bitter',
        ),
        producer: const Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'cbf2025',
      ),
      Drink(
        product: const Product(
          id: 'drink3',
          name: 'Gamma Stout',
          abv: 6.0,
          category: 'beer',
          dispense: 'keg',
          style: 'Stout',
        ),
        producer: const Producer(
          id: 'brewery2',
          name: 'Another Brewery',
          location: 'London',
          products: [],
        ),
        festivalId: 'cbf2025',
      ),
    ];

    setUp(() async {
      DrinkCard.debugBuildCount = 0;
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      const testFestival = Festival(
        id: 'cbf2025',
        name: 'Cambridge Beer Festival 2025',
        dataBaseUrl: 'https://test.example.com/cbf2025',
      );
      final festivalsResponse = FestivalsResponse(
        festivals: [testFestival],
        defaultFestivalId: 'cbf2025',
        baseUrl: 'https://example.com',
        version: '1.0.0',
      );
      when(
        mockFestivalRepository.getFestivals(),
      ).thenAnswer((_) async => festivalsResponse);
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => testDrinks);

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

    Widget createTestWidget() {
      final router = GoRouter(
        initialLocation: '/cbf2025',
        routes: [
          GoRoute(
            path: '/cbf2025',
            builder: (context, state) =>
                ChangeNotifierProvider<BeerProvider>.value(
                  value: provider,
                  child: const DrinksScreen(festivalId: 'cbf2025'),
                ),
          ),
          // Stub for any internal context.go('/') — see validation-and-qa.
          GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    testWidgets(
      'a provider change DrinksScreen does not render leaves DrinkCard '
      'build count unchanged',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Alpha IPA'), findsOneWidget);
        final countBefore = DrinkCard.debugBuildCount;
        expect(
          countBefore,
          greaterThan(0),
          reason: 'Test setup check: cards must have built at least once',
        );

        // themeMode is never read by DrinksScreen or any of its selects.
        await provider.setThemeMode(ThemeMode.dark);
        await tester.pump();

        expect(
          DrinkCard.debugBuildCount,
          countBefore,
          reason:
              'An unrelated provider field change must not rebuild '
              'DrinkCard — this is the literal acceptance bar for #523',
        );
      },
    );

    testWidgets(
      'control: a change that narrows the drink list does increase the '
      'build count',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final countBefore = DrinkCard.debugBuildCount;
        expect(countBefore, greaterThan(0));

        // setSearchQuery changes provider.drinks (selected by DrinksScreen),
        // so this must rebuild the list — proves the counter isn't dead and
        // narrowing selects didn't over-suppress real updates.
        provider.setSearchQuery('Alpha');
        await tester.pumpAndSettle();

        expect(find.text('Alpha IPA'), findsOneWidget);
        expect(find.text('Beta Bitter'), findsNothing);
        expect(DrinkCard.debugBuildCount, greaterThan(countBefore));
      },
    );

    testWidgets(
      'control: rating a drink rebuilds the card and shows the stars (#568)',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // No card shows a rating yet, so DrinkCard's _RatingChip (a
        // non-editable StarRating) is absent from the whole list.
        expect(find.byType(StarRating), findsNothing);
        final countBefore = DrinkCard.debugBuildCount;
        expect(countBefore, greaterThan(0));

        // A userState-only write: it changes no drink's identity and no
        // list length, so provider.drinks stays deep-equal to its previous
        // value even though recompute() assigned a fresh List. That is
        // exactly what a plain context.select cannot observe, because select
        // compares with DeepCollectionEquality and Drink.== is
        // id+festivalId-scoped (drink.dart) — the trap #568 is about.
        when(mockDrinkRepository.setRating(any, any, any)).thenAnswer(
          (_) async => UserDrinkState(
            rating: 4,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await provider.setRating(testDrinks[0], 4);
        await tester.pumpAndSettle();

        expect(
          DrinkCard.debugBuildCount,
          greaterThan(countBefore),
          reason:
              'A rating write must rebuild the visible DrinkCards — this is '
              'the acceptance bar for #568',
        );
        // The user-visible half: the rated card actually renders its stars.
        expect(find.byType(StarRating), findsOneWidget);
      },
    );
  });
}
