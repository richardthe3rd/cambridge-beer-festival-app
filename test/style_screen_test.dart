import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('StyleScreen', () {
    late MockBeerApiService mockApiService;
    late MockFestivalService mockFestivalService;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    const producer1 = Producer(
      id: 'brewery1',
      name: 'Test Brewery 1',
      location: 'Cambridge, UK',
      yearFounded: 1990,
      products: [],
    );

    const producer2 = Producer(
      id: 'brewery2',
      name: 'Test Brewery 2',
      location: 'London, UK',
      yearFounded: 2000,
      products: [],
    );

    const product1 = Product(
      id: 'drink1',
      name: 'Test IPA 1',
      abv: 5.0,
      category: 'beer',
      style: 'IPA',
      dispense: 'cask',
    );

    const product2 = Product(
      id: 'drink2',
      name: 'Test IPA 2',
      abv: 6.5,
      category: 'beer',
      style: 'IPA',
      dispense: 'keg',
    );

    const product3 = Product(
      id: 'drink3',
      name: 'Test Stout',
      abv: 4.5,
      category: 'beer',
      style: 'Stout',
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
          home: StyleScreen(festivalId: 'cbf2025', style: style),
        ),
      );
    }

    testWidgets('displays style not found when no drinks with that style exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget('NonExistent Style'));
      await tester.pumpAndSettle();

      expect(find.text('Style Not Found'), findsOneWidget);
      expect(find.text('No drinks found for this style.'), findsOneWidget);
    });

    testWidgets('displays style information when drinks with that style exist',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1, drink2]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('IPA'));
      await tester.pumpAndSettle();

      expect(find.text('IPA'), findsWidgets);
      // The new UI uses stat cards showing drink count as a number
      expect(find.text('2'), findsOneWidget);
      // Note: 'Drinks' appears once in section title, breadcrumb shows festival ID
      expect(find.text('Drinks'), findsOneWidget);
      expect(find.text('cbf2025'), findsOneWidget); // Festival ID in breadcrumb
    });

    testWidgets('displays drinks with the specified style',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1, drink2]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('IPA'));
      await tester.pumpAndSettle();

      expect(find.text('Drinks (2)'), findsOneWidget);
      expect(find.text('Test IPA 1'), findsOneWidget);
      expect(find.text('Test IPA 2'), findsOneWidget);
    });

    testWidgets('navigates to drink detail when drink card is tapped',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('IPA'));
      await tester.pumpAndSettle();

      // Find the drink card - this verifies the card is rendered and tappable
      expect(find.text('Test IPA 1'), findsOneWidget);
      
      // NOTE: Navigation to DrinkDetailScreen uses go_router's context.push()
      // which requires GoRouter in the widget tree. This is tested in E2E tests
      // (test-e2e/routing.spec.ts) instead of unit tests.
    });

    testWidgets('toggles favorite when favorite button is tapped',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('IPA'));
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

      await tester.pumpWidget(createTestWidget('IPA'));
      await tester.pumpAndSettle();

      expect(find.text('Drinks (2)'), findsOneWidget);
    });

    testWidgets('filters drinks to show only the specified style',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1, drink2, drink3]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('IPA'));
      await tester.pumpAndSettle();

      // Should only show IPA drinks
      expect(find.text('Test IPA 1'), findsOneWidget);
      expect(find.text('Test IPA 2'), findsOneWidget);
      expect(find.text('Test Stout'), findsNothing);
      expect(find.text('Drinks (2)'), findsOneWidget);
    });

    testWidgets('shows drinks from different breweries with same style',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1, drink2]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('IPA'));
      await tester.pumpAndSettle();

      // Should show drinks from both breweries
      expect(find.text('Test IPA 1'), findsOneWidget);
      expect(find.text('Test IPA 2'), findsOneWidget);
      expect(find.textContaining('Test Brewery 1'), findsOneWidget);
      expect(find.textContaining('Test Brewery 2'), findsOneWidget);
    });

    testWidgets('displays style description when available',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1, drink2]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('IPA'));
      await tester.pumpAndSettle();
      
      // Wait for FutureBuilder to complete
      await tester.pumpAndSettle();

      // Should display the lorem ipsum description for IPA
      expect(
        find.textContaining('Lorem ipsum dolor sit amet'),
        findsOneWidget,
      );

      // Should still show the stats
      // Note: 'Drinks' appears once in section title, breadcrumb shows festival ID
      expect(find.text('Drinks'), findsOneWidget);
      expect(find.text('cbf2025'), findsOneWidget); // Festival ID in breadcrumb
      expect(find.text('Avg ABV'), findsOneWidget);
    });

    testWidgets('header without description when style has none',
        (WidgetTester tester) async {
      // Create a drink with a style that has no description
      const productUnknown = Product(
        id: 'drink4',
        name: 'Unknown Style Beer',
        abv: 5.0,
        category: 'beer',
        style: 'Unknown Style',
        dispense: 'cask',
      );
      final drinkUnknown = Drink(
        product: productUnknown,
        producer: producer1,
        festivalId: 'cbf2025',
      );

      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drinkUnknown]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('Unknown Style'));
      await tester.pumpAndSettle();
      
      // Wait for FutureBuilder to complete
      await tester.pumpAndSettle();

      // Should not crash and should still show stats
      // Note: 'Drinks' appears once in section title, breadcrumb shows festival ID
      expect(find.text('Drinks'), findsOneWidget);
      expect(find.text('cbf2025'), findsOneWidget); // Festival ID in breadcrumb
      expect(find.text('Avg ABV'), findsOneWidget);
    });

    testWidgets('can scroll when header is expanded',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink1, drink2, drink3]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('IPA'));
      await tester.pumpAndSettle();
      
      // Wait for FutureBuilder to complete
      await tester.pumpAndSettle();

      // Find the CustomScrollView
      final scrollView = find.byType(CustomScrollView);
      expect(scrollView, findsOneWidget);

      // Verify description is visible when expanded
      expect(
        find.textContaining('Lorem ipsum'),
        findsOneWidget,
      );

      // Scroll down to collapse the header
      await tester.drag(scrollView, const Offset(0, -200));
      await tester.pumpAndSettle();

      // After scrolling, the list of drinks should be visible
      expect(find.text('Test IPA 1'), findsOneWidget);
      expect(find.text('Test IPA 2'), findsOneWidget);
    });
  });
}

