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
  group('StyleScreen Screenshot Tests', () {
    late MockBeerApiService mockApiService;
    late MockFestivalService mockFestivalService;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    const producer1 = Producer(
      id: 'brewery1',
      name: 'Cambridge Brewing Company',
      location: 'Cambridge, UK',
      yearFounded: 1990,
      products: [],
    );

    const producer2 = Producer(
      id: 'brewery2',
      name: 'London Craft Ales',
      location: 'London, UK',
      yearFounded: 2000,
      products: [],
    );

    const product1 = Product(
      id: 'drink1',
      name: 'Hoppy Heaven IPA',
      abv: 6.2,
      category: 'beer',
      style: 'IPA',
      dispense: 'cask',
    );

    const product2 = Product(
      id: 'drink2',
      name: 'Golden Crown IPA',
      abv: 5.8,
      category: 'beer',
      style: 'IPA',
      dispense: 'keg',
    );

    const product3 = Product(
      id: 'drink3',
      name: 'Citrus Burst IPA',
      abv: 6.5,
      category: 'beer',
      style: 'IPA',
      dispense: 'cask',
    );

    final drink1 = Drink(product: product1, producer: producer1, festivalId: 'cbf2025');
    final drink2 = Drink(product: product2, producer: producer2, festivalId: 'cbf2025');
    final drink3 = Drink(product: product3, producer: producer1, festivalId: 'cbf2025');

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockApiService = MockBeerApiService();
      mockFestivalService = MockFestivalService();
      mockAnalyticsService = MockAnalyticsService();
      provider = BeerProvider(
        apiService: mockApiService,
        festivalService: mockFestivalService,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
    });

    tearDown(() {
      provider.dispose();
    });

    Widget createTestWidget(String style) {
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
          home: StyleScreen(style: style),
        ),
      );
    }

    testWidgets('StyleScreen with description - light theme',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1, drink2, drink3]);
      await provider.loadDrinks();

      // Set a larger screen size for better screenshot
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(createTestWidget('IPA'));
      await tester.pumpAndSettle();
      
      // Wait for FutureBuilder to load description
      await tester.pumpAndSettle();

      // Take a screenshot
      await expectLater(
        find.byType(StyleScreen),
        matchesGoldenFile('goldens/style_screen_with_description_light.png'),
      );
    });

    testWidgets('StyleScreen with description - dark theme',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1, drink2, drink3]);
      await provider.loadDrinks();

      // Set a larger screen size for better screenshot
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFD97706),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            home: const StyleScreen(style: 'IPA'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Wait for FutureBuilder to load description
      await tester.pumpAndSettle();

      // Take a screenshot
      await expectLater(
        find.byType(StyleScreen),
        matchesGoldenFile('goldens/style_screen_with_description_dark.png'),
      );
    });
  });
}
