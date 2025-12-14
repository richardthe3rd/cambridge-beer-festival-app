import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('BreweryScreen', () {
    late MockBeerApiService mockApiService;
    late MockFestivalService mockFestivalService;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    const producer1 = Producer(
      id: 'brewery1',
      name: 'Test Brewery',
      location: 'Cambridge, UK',
      yearFounded: 1990,
      products: [],
    );

    const product1 = Product(
      id: 'drink1',
      name: 'Test Beer 1',
      abv: 5.0,
      category: 'beer',
      dispense: 'cask',
    );

    const product2 = Product(
      id: 'drink2',
      name: 'Test Beer 2',
      abv: 4.5,
      category: 'beer',
      dispense: 'cask',
    );

    final drink1 = Drink(product: product1, producer: producer1, festivalId: 'cbf2025');
    final drink2 = Drink(product: product2, producer: producer1, festivalId: 'cbf2025');

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockApiService = MockBeerApiService();
      mockFestivalService = MockFestivalService();
      mockAnalyticsService = MockAnalyticsService();
      
      // Mock fetchFestivals to return a test festival
      const testFestival = Festival(
        id: 'cbf2025',
        name: 'Cambridge Beer Festival 2025',
        dataBaseUrl: 'https://test.example.com/cbf2025',
      );
      final festivalsResponse = FestivalsResponse(
        festivals: [testFestival],
        defaultFestivalId: 'cbf2025',
        version: '1.0.0',
      );
      when(mockFestivalService.fetchFestivals())
          .thenAnswer((_) async => festivalsResponse);
      
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

    Widget createTestWidget(String breweryId) {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(
          home: BreweryScreen(breweryId: breweryId),
        ),
      );
    }

    testWidgets('displays brewery not found when brewery does not exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget('nonexistent'));
      await tester.pumpAndSettle();

      expect(find.text('Brewery Not Found'), findsOneWidget);
      expect(find.text('This brewery could not be found.'), findsOneWidget);
    });

    testWidgets('displays brewery information when brewery exists',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1, drink2]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('brewery1'));
      await tester.pumpAndSettle();

      expect(find.text('Test Brewery'), findsWidgets);
      expect(find.text('Cambridge, UK'), findsOneWidget);
      expect(find.text('Est. 1990'), findsOneWidget);
      expect(find.text('2 drinks'), findsOneWidget);
    });

    testWidgets('displays drinks from the brewery',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1, drink2]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('brewery1'));
      await tester.pumpAndSettle();

      expect(find.text('Drinks (2)'), findsOneWidget);
      expect(find.text('Test Beer 1'), findsOneWidget);
      expect(find.text('Test Beer 2'), findsOneWidget);
    });

    testWidgets('navigates to drink detail when drink card is tapped',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('brewery1'));
      await tester.pumpAndSettle();

      // Find the drink card - this verifies the card is rendered and tappable
      expect(find.text('Test Beer 1'), findsOneWidget);
      
      // NOTE: Navigation to DrinkDetailScreen uses go_router's context.push()
      // which requires GoRouter in the widget tree. This is tested in E2E tests
      // (test-e2e/routing.spec.ts) instead of unit tests.
    });

    testWidgets('toggles favorite when favorite button is tapped',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('brewery1'));
      await tester.pumpAndSettle();

      expect(drink1.isFavorite, false);

      // Find and tap the favorite button
      final favoriteButton = find.descendant(
        of: find.byType(DrinkCard),
        matching: find.byIcon(Icons.favorite_border),
      );
      await tester.tap(favoriteButton);
      await tester.pumpAndSettle();

      expect(drink1.isFavorite, true);
    });

    testWidgets('displays correct count of drinks',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1, drink2]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('brewery1'));
      await tester.pumpAndSettle();

      expect(find.text('Drinks (2)'), findsOneWidget);
    });

    testWidgets('does not display year founded when null',
        (WidgetTester tester) async {
      const producerNoYear = Producer(
        id: 'brewery2',
        name: 'New Brewery',
        location: 'London, UK',
        yearFounded: null,
        products: [],
      );
      final drink = Drink(product: product1, producer: producerNoYear, festivalId: 'cbf2025');
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('brewery2'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Est.'), findsNothing);
    });

    testWidgets('handles empty location',
        (WidgetTester tester) async {
      const producerNoLocation = Producer(
        id: 'brewery3',
        name: 'Mystery Brewery',
        location: '',
        yearFounded: 2020,
        products: [],
      );
      final drink = Drink(product: product1, producer: producerNoLocation, festivalId: 'cbf2025');
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('brewery3'));
      await tester.pumpAndSettle();

      expect(find.text('Mystery Brewery'), findsWidgets);
      expect(find.byIcon(Icons.location_on), findsNothing);
    });

    testWidgets('filters drinks to show only from requested brewery',
        (WidgetTester tester) async {
      const producer2 = Producer(
        id: 'brewery2',
        name: 'Other Brewery',
        location: 'London, UK',
        yearFounded: null,
        products: [],
      );
      const product3 = Product(
        id: 'drink3',
        name: 'Other Beer',
        abv: 6.0,
        category: 'beer',
        dispense: 'keg',
      );
      final drink3 = Drink(product: product3, producer: producer2, festivalId: 'cbf2025');

      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1, drink2, drink3]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('brewery1'));
      await tester.pumpAndSettle();

      // Should only show drinks from brewery1
      expect(find.text('Test Beer 1'), findsOneWidget);
      expect(find.text('Test Beer 2'), findsOneWidget);
      expect(find.text('Other Beer'), findsNothing);
      expect(find.text('Drinks (2)'), findsOneWidget);
    });
  });
}
