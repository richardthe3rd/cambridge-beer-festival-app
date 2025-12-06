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
  group('DrinkDetailScreen', () {
    late MockBeerApiService mockApiService;
    late MockFestivalService mockFestivalService;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    final festival = Festival(
      id: 'cbf2025',
      name: 'Cambridge Beer Festival 2025',
      dataBaseUrl: 'https://example.com',
      hashtag: '#CBF2025',
    );

    final producer = Producer(
      id: 'brewery1',
      name: 'Test Brewery',
      location: 'Cambridge, UK',
      yearFounded: 1990,
      products: [],
    );

    final product = Product(
      id: 'drink1',
      name: 'Test Beer',
      abv: 5.0,
      category: 'beer',
      dispense: 'cask',
      style: 'IPA',
      bar: 'Main Bar',
      notes: 'A hoppy beer with citrus notes',
      allergens: {'gluten': 1, 'sulphites': 1},
    );

    final drink = Drink(product: product, producer: producer, festivalId: 'cbf2025');

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
      await provider.setFestival(festival);
    });

    tearDown(() {
      provider.dispose();
    });

    Widget createTestWidget(String drinkId) {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(
          home: DrinkDetailScreen(drinkId: drinkId),
        ),
      );
    }

    testWidgets('displays drink not found when drink does not exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget('nonexistent'));
      await tester.pumpAndSettle();

      expect(find.text('Drink Not Found'), findsOneWidget);
      expect(find.text('This drink could not be found.'), findsOneWidget);
    });

    testWidgets('displays drink information when drink exists',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('Test Beer'), findsOneWidget);
      expect(find.text('Test Brewery'), findsNWidgets(2)); // Appears in header and brewery section
      expect(find.text('Cambridge, UK'), findsNWidgets(2)); // Appears in header and brewery section
    });

    testWidgets('displays drink details chips',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('5.0%'), findsNWidgets(2)); // Appears in chips and details section
      expect(find.text('IPA'), findsNWidgets(2)); // Appears in chips and details section
      expect(find.text('cask'), findsNWidgets(2)); // Appears in chips and details section
      expect(find.text('Main Bar'), findsNWidgets(2)); // Appears in chips and details section
    });

    testWidgets('displays description when notes exist',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('Description'), findsOneWidget);
      expect(find.text('A hoppy beer with citrus notes'), findsOneWidget);
    });

    testWidgets('displays allergen information',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Contains:'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('displays details section',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('ABV'), findsOneWidget);
      expect(find.text('Dispense'), findsOneWidget);
      expect(find.text('Style'), findsOneWidget);
      expect(find.text('Bar'), findsOneWidget);
    });

    testWidgets('displays rating section',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('Your Rating'), findsOneWidget);
      expect(find.byType(StarRating), findsOneWidget);
    });

    testWidgets('displays brewery section',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('Brewery'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('has share button in app bar',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('has favorite button in app bar',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('toggles favorite when favorite button is tapped',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(drink.isFavorite, false);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      // Tap favorite button
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(drink.isFavorite, true);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('navigates to brewery screen when brewery card is tapped',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      // Find brewery card and ensure it's visible
      final breweryCard = find.ancestor(
        of: find.text('Test Brewery'),
        matching: find.byType(Card),
      );
      await tester.ensureVisible(breweryCard.last);
      await tester.pumpAndSettle();
      
      await tester.tap(breweryCard.last);
      await tester.pumpAndSettle();

      // Should navigate to brewery screen
      expect(find.byType(BreweryScreen), findsOneWidget);
    });

    testWidgets('does not display description when notes are null',
        (WidgetTester tester) async {
      final productNoNotes = Product(
        id: 'drink2',
        name: 'Simple Beer',
        abv: 4.0,
        category: 'beer',
        dispense: 'keg',
        notes: null,
      );
      final drinkNoNotes = Drink(product: productNoNotes, producer: producer, festivalId: 'cbf2025');
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drinkNoNotes]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink2'));
      await tester.pumpAndSettle();

      expect(find.text('Description'), findsNothing);
    });

    testWidgets('displays rating value when drink has rating',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();
      
      drink.rating = 4;

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('4/5'), findsOneWidget);
    });

    testWidgets('does not display rating value when drink has no rating',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();
      
      drink.rating = null;

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('/5'), findsNothing);
    });

    testWidgets('updates rating when set through provider',
        (WidgetTester tester) async {
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(drink.rating, null);

      // Simulate rating change through provider
      provider.setRating(drink, 5);
      await tester.pumpAndSettle();

      expect(drink.rating, 5);
      expect(find.text('5/5'), findsOneWidget);
    });
  });
}
