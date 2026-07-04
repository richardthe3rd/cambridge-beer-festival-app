import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_test.mocks.dart';

void main() {
  group('MyFestivalScreen', () {
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

    final wantToTryDrink = Drink(
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

    final tastedOnlyDrink = Drink(
      product: const Product(
        id: 'drink-b',
        name: 'Beta Bitter',
        abv: 3.8,
        category: 'beer',
        dispense: 'cask',
      ),
      producer: producer,
      festivalId: 'cbf2025',
    );

    final bothDrink = Drink(
      product: const Product(
        id: 'drink-c',
        name: 'Gamma Gose',
        abv: 4.5,
        category: 'beer',
        dispense: 'keg',
      ),
      producer: producer,
      festivalId: 'cbf2025',
    );

    Future<void> setUpProvider() async {
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

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
    }

    Widget createTestWidget() {
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
          GoRoute(
            path: '/:festivalId/drink/:category/:id',
            builder: (context, state) =>
                const Scaffold(body: Text('Drink Detail')),
          ),
          // Stub root route so any context.go('/') calls don't throw.
          GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    testWidgets(
      'shows want-to-try drink under Want to Try and tasted drink under '
      'Tasted, and a both-flagged drink only under Tasted',
      (tester) async {
        await setUpProvider();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [wantToTryDrink, tastedOnlyDrink, bothDrink]);
        await provider.loadDrinks();

        final now = DateTime(2026, 6, 10, 18, 30);
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-a': UserDrinkState(
            wantToTry: true,
            createdAt: now,
            updatedAt: now,
          ),
          'drink-b': UserDrinkState(
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
          'drink-c': UserDrinkState(
            wantToTry: true,
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Want-to-try-only drink appears once, as a want-to-try row.
        expect(
          find.byKey(const ValueKey('want-to-try-drink-a')),
          findsOneWidget,
        );
        expect(find.text('Alpha Ale'), findsOneWidget);

        // Tasted-only drink appears once, as a tasted row.
        expect(find.byKey(const ValueKey('tasted-drink-b')), findsOneWidget);
        expect(find.text('Beta Bitter'), findsOneWidget);

        // Both-flagged drink appears ONLY under Tasted — Tasted takes
        // display priority per vision.md.
        expect(find.byKey(const ValueKey('tasted-drink-c')), findsOneWidget);
        expect(find.byKey(const ValueKey('want-to-try-drink-c')), findsNothing);
        expect(find.text('Gamma Gose'), findsOneWidget);
      },
    );

    testWidgets('placeholder row renders when catalogue entry is not loaded', (
      tester,
    ) async {
      await setUpProvider();
      // Catalogue does not include this drink — simulates not-yet-loaded.
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);
      await provider.loadDrinks();

      final now = DateTime.now();
      when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
        'unloaded-drink': UserDrinkState(
          wantToTry: true,
          createdAt: now,
          updatedAt: now,
        ),
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('placeholder-unloaded-drink')),
        findsOneWidget,
      );
      expect(find.text('unloaded-drink'), findsOneWidget);
      expect(find.text('Loading details…'), findsOneWidget);
    });

    testWidgets('shows empty state when both sections have no entries', (
      tester,
    ) async {
      await setUpProvider();
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);
      await provider.loadDrinks();
      when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Nothing in My Festival yet'), findsOneWidget);
    });

    group('semantics', () {
      testWidgets('section header and row have Semantics labels', (
        tester,
      ) async {
        await setUpProvider();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [wantToTryDrink]);
        await provider.loadDrinks();

        final now = DateTime.now();
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-a': UserDrinkState(
            wantToTry: true,
            createdAt: now,
            updatedAt: now,
          ),
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Section header Semantics label.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Want to Try section, 1 drink',
          ),
          findsOneWidget,
        );

        // Row Semantics label.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label ==
                    'Alpha Ale, by Test Brewery, want to try',
          ),
          findsOneWidget,
        );
      });
    });
  });
}
