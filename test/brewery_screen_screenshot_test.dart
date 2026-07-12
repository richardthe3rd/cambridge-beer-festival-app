import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('BreweryScreen Screenshot Tests', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    // A producer with notes and a founding year so the "about this brewery"
    // section and the "Founded" fact both render in the golden.
    const producer = Producer(
      id: 'brewery1',
      name: 'Cambridge Brewing Company',
      location: 'Cambridge, UK',
      yearFounded: 1990,
      notes:
          'A family-run brewery on the banks of the Cam, brewing cask ales '
          'and ciders since 1990.',
      products: [],
    );

    // Two beers and a cider — two categories, so the dominant-category accent
    // (beer, amber) is exercised — with two distinct styles so the "Styles"
    // fact appears.
    const productIpa = Product(
      id: 'drink1',
      name: 'Hoppy Heaven IPA',
      abv: 6.2,
      category: 'beer',
      style: 'IPA',
      dispense: 'cask',
    );

    const productStout = Product(
      id: 'drink2',
      name: 'Midnight Stout',
      abv: 4.8,
      category: 'beer',
      style: 'Stout',
      dispense: 'cask',
    );

    const productCider = Product(
      id: 'drink3',
      name: 'Orchard Gold',
      abv: 5.5,
      category: 'cider',
      dispense: 'keg',
    );

    final drink1 = Drink(
      product: productIpa,
      producer: producer,
      festivalId: 'cbf2025',
    );
    final drink2 = Drink(
      product: productStout,
      producer: producer,
      festivalId: 'cbf2025',
    );
    final drink3 = Drink(
      product: productCider,
      producer: producer,
      festivalId: 'cbf2025',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [DefaultFestivals.cambridge2025],
          defaultFestivalId: DefaultFestivals.cambridge2025.id,
          version: '1.0',
          baseUrl: 'https://data.cambeerfestival.app',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
    });

    tearDown(() {
      provider.dispose();
    });

    Widget buildApp(Brightness brightness) {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2B3170),
              brightness: brightness,
            ),
            useMaterial3: true,
          ),
          home: const BreweryScreen(
            festivalId: 'cbf2025',
            breweryId: 'brewery1',
          ),
        ),
      );
    }

    testWidgets('BreweryScreen identity hero - light theme', (
      WidgetTester tester,
    ) async {
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => [drink1, drink2, drink3]);
      await provider.loadDrinks();

      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(buildApp(Brightness.light));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(BreweryScreen),
        matchesGoldenFile('goldens/brewery_screen_light.png'),
      );
    });

    testWidgets('BreweryScreen identity hero - dark theme', (
      WidgetTester tester,
    ) async {
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => [drink1, drink2, drink3]);
      await provider.loadDrinks();

      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(buildApp(Brightness.dark));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(BreweryScreen),
        matchesGoldenFile('goldens/brewery_screen_dark.png'),
      );
    });
  });
}
