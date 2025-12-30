import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('DrinkDetailScreen Screenshot Tests', () {
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
      yearFounded: 1990,
      products: [],
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      
      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [DefaultFestivals.cambridge2025],
          defaultFestivalId: DefaultFestivals.cambridge2025.id,
          version: '1.0',
          baseUrl: 'https://data.cambeerfestival.app',
        ),
      );
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();
      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
      await provider.setFestival(festival);
    });

    tearDown(() {
      provider.dispose();
    });

    Widget createTestWidget(String drinkId) {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFD97706),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          home: DrinkDetailScreen(festivalId: 'cbf2025', drinkId: drinkId),
        ),
      );
    }

    testWidgets('DrinkDetailScreen with long drink name - light theme',
        (WidgetTester tester) async {
      // Create a drink with a very long name to demonstrate the issue
      const productLongName = Product(
        id: 'drink1',
        name: 'Super Duper Extra Long Name Imperial Double IPA With Many Words',
        abv: 7.5,
        category: 'beer',
        dispense: 'cask',
        style: 'IPA',
        bar: 'Main Bar',
        notes: 'A hoppy beer with citrus notes',
      );

      final drinkLongName = Drink(product: productLongName, producer: producer, festivalId: 'cbf2025');

      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drinkLongName]);
      await provider.loadDrinks();

      // Set a typical mobile screen size
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      // Take a screenshot
      await expectLater(
        find.byType(DrinkDetailScreen),
        matchesGoldenFile('goldens/drink_detail_screen_long_name_light.png'),
      );
    });

    testWidgets('DrinkDetailScreen with medium drink name - light theme',
        (WidgetTester tester) async {
      const productMediumName = Product(
        id: 'drink2',
        name: 'Golden Crown IPA',
        abv: 5.8,
        category: 'beer',
        dispense: 'keg',
        style: 'IPA',
        bar: 'Main Bar',
      );

      final drinkMediumName = Drink(product: productMediumName, producer: producer, festivalId: 'cbf2025');

      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drinkMediumName]);
      await provider.loadDrinks();

      // Set a typical mobile screen size
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(createTestWidget('drink2'));
      await tester.pumpAndSettle();

      // Take a screenshot
      await expectLater(
        find.byType(DrinkDetailScreen),
        matchesGoldenFile('goldens/drink_detail_screen_medium_name_light.png'),
      );
    });
  });
}
