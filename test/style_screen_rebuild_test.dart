// Regression/proof test for issue #523: StyleScreen used to
// context.watch<BeerProvider>() as a whole, so a change to any provider
// field — including one StyleScreen never renders, like themeMode —
// rebuilt the entire screen and, with it, every DrinkCard in the style's
// drink list. Narrowing to per-concern context.select calls, plus a
// Selector<BeerProvider, List<Drink>> with an identity-based shouldRebuild
// for allDrinks (#564 made it a fresh List on every catalogue load and
// personal-state write, but Drink.== is id-scoped, so a plain
// context.select on it — using the package's default deep equality — would
// still miss a userState-only change), means an unrelated notifyListeners()
// no longer touches StyleScreen.build() at all.
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
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('StyleScreen narrowed rebuilds (#523)', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    const producer1 = Producer(
      id: 'brewery1',
      name: 'Test Brewery',
      location: 'Cambridge',
      products: [],
    );

    final drink1 = Drink(
      product: const Product(
        id: 'drink1',
        name: 'Test IPA 1',
        abv: 5.0,
        category: 'beer',
        style: 'IPA',
        dispense: 'cask',
      ),
      producer: producer1,
      festivalId: 'cbf2025',
    );
    final drink2 = Drink(
      product: const Product(
        id: 'drink2',
        name: 'Test IPA 2',
        abv: 6.5,
        category: 'beer',
        style: 'IPA',
        dispense: 'keg',
      ),
      producer: producer1,
      festivalId: 'cbf2025',
    );

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
      ).thenAnswer((_) async => [drink1, drink2]);

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
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: StyleScreen(festivalId: 'cbf2025', style: 'ipa'),
        ),
      );
    }

    testWidgets(
      'a provider change StyleScreen does not render leaves DrinkCard '
      'build count unchanged',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Test IPA 1'), findsOneWidget);
        final countBefore = DrinkCard.debugBuildCount;
        expect(
          countBefore,
          greaterThan(0),
          reason: 'Test setup check: cards must have built at least once',
        );

        // themeMode is never read by StyleScreen or any of its selects.
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
      'control: toggling a favourite on a style drink does increase the '
      'build count',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final countBefore = DrinkCard.debugBuildCount;
        expect(countBefore, greaterThan(0));

        // allDrinks is a fresh List on every personal-state write (#564), so
        // this exercises the direct proof: StyleScreen's
        // Selector<BeerProvider, List<Drink>> (identity-based shouldRebuild)
        // does rebuild here.
        when(mockDrinkRepository.toggleFavorite(any, any)).thenAnswer(
          (_) async => UserDrinkState(
            wantToTry: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await provider.toggleFavorite(drink1);
        await tester.pumpAndSettle();

        expect(DrinkCard.debugBuildCount, greaterThan(countBefore));
      },
    );
  });
}
