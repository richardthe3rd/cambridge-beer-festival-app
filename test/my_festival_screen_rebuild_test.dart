// Regression/proof test for issue #563: MyFestivalScreen used to
// context.watch<BeerProvider>() as a whole, so a change to any provider
// field — including one this screen never renders, like the search query —
// rebuilt the entire screen. Narrowing to context.select calls for exactly
// currentFestival.id (the festival-flash guard), currentFestival.name (app
// bar title/PageTitle), and myFestivalEntries means an unrelated
// notifyListeners() no longer touches MyFestivalScreen.build() at all.
//
// Rebuilds are counted with MyFestivalScreen.debugBuildCount, the
// assert-gated counter used by DrinkCard/ProviderInitializer/
// DrinkDetailScreen/AboutScreen for the same purpose. The negative case
// below is paired with a control case that proves the counter is live, so
// neither can pass on a dead counter.
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('MyFestivalScreen narrowed rebuilds (#563)', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    const festival = Festival(
      id: 'cbf2025',
      name: 'Cambridge Beer Festival 2025',
      dataBaseUrl: 'https://example.com',
    );

    const producer = Producer(
      id: 'brewery1',
      name: 'Test Brewery',
      location: 'Cambridge, UK',
      products: [],
    );

    final drink = Drink(
      product: const Product(
        id: 'drink-a',
        name: 'Alpha Ale',
        abv: 4.2,
        category: 'beer',
        dispense: 'cask',
      ),
      producer: producer,
      festivalId: 'cbf2025',
    );

    setUp(() async {
      MyFestivalScreen.debugBuildCount = 0;
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
      when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({});

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

    Future<void> pumpScreen(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/${festival.id}/favorites',
        routes: [
          GoRoute(
            path: '/:festivalId/favorites',
            builder: (context, state) =>
                ChangeNotifierProvider<BeerProvider>.value(
                  value: provider,
                  child: MyFestivalScreen(
                    festivalId: state.pathParameters['festivalId']!,
                  ),
                ),
          ),
          GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'a provider change unrelated to this screen leaves the build count '
      'unchanged',
      (tester) async {
        await pumpScreen(tester);
        final buildsBefore = MyFestivalScreen.debugBuildCount;

        // The search query is never read by MyFestivalScreen or its three
        // narrowed selects, and has no path to this screen other than the
        // provider.
        provider.setSearchQuery('ipa');
        await tester.pump();

        expect(
          MyFestivalScreen.debugBuildCount,
          buildsBefore,
          reason:
              'An unrelated provider field change must not rebuild '
              'MyFestivalScreen — this is the literal acceptance bar for '
              '#563',
        );
      },
    );

    testWidgets(
      'control: adding a want-to-try entry does rebuild it and shows the '
      'new row',
      (tester) async {
        await pumpScreen(tester);
        expect(find.text('Nothing in My Festival yet'), findsOneWidget);
        final buildsBefore = MyFestivalScreen.debugBuildCount;

        // myFestivalEntries reads through
        // _drinkRepository.getPersonalEntries on every cache miss (it is not
        // derived from Drink.userState), so the mock's stub must be updated
        // too — toggleFavorite alone only bumps the revision that invalidates
        // the cache.
        final now = DateTime.now();
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-a': UserDrinkState(
            wantToTry: true,
            createdAt: now,
            updatedAt: now,
          ),
        });
        when(mockDrinkRepository.toggleFavorite(any, any)).thenAnswer(
          (_) async =>
              UserDrinkState(wantToTry: true, createdAt: now, updatedAt: now),
        );
        await provider.toggleFavorite(drink);
        await tester.pump();

        expect(
          MyFestivalScreen.debugBuildCount,
          greaterThan(buildsBefore),
          reason: 'Test setup check: the counter must be provably live',
        );
        expect(find.text('Alpha Ale'), findsOneWidget);
        expect(find.text('Nothing in My Festival yet'), findsNothing);
      },
    );
  });
}
