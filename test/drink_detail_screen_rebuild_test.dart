// Regression/proof test for issue #523: DrinkDetailScreen used to
// context.watch<BeerProvider>() as a whole, so a change to any provider
// field — including one this screen never renders, like themeMode or the
// drinks-screen search query — rebuilt the entire screen.
//
// This screen renders its "Similar Drinks" carousel with a private
// _SimilarDrinkCard, not the shared DrinkCard, so DrinkCard.debugBuildCount
// cannot observe this screen's rebuilds (see brewery/style's rebuild tests
// for that pattern). DrinkDetailScreen.debugBuildCount (assert-gated,
// lib/screens/drink_detail_screen.dart) counts real calls to
// _DrinkDetailScreenState.build() instead.
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('DrinkDetailScreen narrowed rebuilds (#523)', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    const festival = Festival(
      id: 'cbf2025',
      name: 'Cambridge Beer Festival 2025',
      dataBaseUrl: 'https://example.com',
      hashtag: '#CBF2025',
    );

    const producer = Producer(
      id: 'brewery1',
      name: 'Test Brewery',
      location: 'Cambridge, UK',
      products: [],
    );

    final drink = Drink(
      product: const Product(
        id: 'drink1',
        name: 'Test Beer',
        abv: 5.0,
        category: 'beer',
        dispense: 'cask',
        style: 'IPA',
      ),
      producer: producer,
      festivalId: 'cbf2025',
    );

    setUp(() async {
      DrinkDetailScreen.debugBuildCount = 0;
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [festival],
          defaultFestivalId: festival.id,
          version: '1.0',
          baseUrl: 'https://example.com',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
      await provider.setFestival(festival);
      await provider.loadDrinks();
    });

    tearDown(() {
      provider.dispose();
    });

    Widget createTestWidget() {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: DrinkDetailScreen(festivalId: 'cbf2025', drinkId: 'drink1'),
        ),
      );
    }

    testWidgets(
      'a provider change this screen does not render leaves the build '
      'count unchanged',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Test Beer'), findsWidgets);
        final countBefore = DrinkDetailScreen.debugBuildCount;
        expect(
          countBefore,
          greaterThan(0),
          reason: 'Test setup check: the screen must have built at least once',
        );

        // searchQuery belongs to DrinksScreen, not DrinkDetailScreen — this
        // screen never selects it.
        provider.setSearchQuery('ipa');
        await tester.pump();

        expect(
          DrinkDetailScreen.debugBuildCount,
          countBefore,
          reason:
              'An unrelated provider field change must not rebuild '
              'DrinkDetailScreen — this is the literal acceptance bar for #523',
        );

        // themeMode is likewise never selected by this screen.
        await provider.setThemeMode(ThemeMode.dark);
        await tester.pump();

        expect(
          DrinkDetailScreen.debugBuildCount,
          countBefore,
          reason: 'A theme-mode change must not rebuild DrinkDetailScreen',
        );
      },
    );

    testWidgets(
      'control: toggling this drink\'s favourite does increase the build '
      'count and the visible want-to-try state',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final countBefore = DrinkDetailScreen.debugBuildCount;
        expect(countBefore, greaterThan(0));
        expect(provider.getDrinkById('drink1')!.isFavorite, isFalse);
        expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

        // allDrinks is mutated in place by _replaceDrink, so this exercises
        // the trap the plan calls out: a naive
        // context.select((p) => p.allDrinks) would never rebuild here.
        when(mockDrinkRepository.toggleFavorite(any, any)).thenAnswer(
          (_) async => UserDrinkState(
            wantToTry: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await provider.toggleFavorite(drink);
        await tester.pumpAndSettle();

        expect(
          DrinkDetailScreen.debugBuildCount,
          greaterThan(countBefore),
          reason: 'The user\'s own favourite toggle must rebuild the screen',
        );
        // Deep assertion, not just the counter: the rendered want-to-try
        // state actually flips.
        expect(provider.getDrinkById('drink1')!.isFavorite, isTrue);
        expect(find.byIcon(Icons.bookmark), findsOneWidget);
        expect(find.byIcon(Icons.bookmark_border), findsNothing);
      },
    );

    testWidgets(
      'control: setting this drink\'s rating does increase the build count '
      'and the visible star rating',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final countBefore = DrinkDetailScreen.debugBuildCount;
        expect(countBefore, greaterThan(0));
        expect(find.byIcon(Icons.star_border), findsNWidgets(5));

        when(mockDrinkRepository.setRating(any, any, any)).thenAnswer(
          (_) async => UserDrinkState(
            rating: 4,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await provider.setRating(drink, 4);
        await tester.pumpAndSettle();

        expect(
          DrinkDetailScreen.debugBuildCount,
          greaterThan(countBefore),
          reason: 'The user\'s own rating change must rebuild the screen',
        );
        expect(provider.getDrinkById('drink1')!.rating, 4);
        expect(find.byIcon(Icons.star), findsNWidgets(4));
        expect(find.byIcon(Icons.star_border), findsNWidgets(1));
      },
    );
  });
}
