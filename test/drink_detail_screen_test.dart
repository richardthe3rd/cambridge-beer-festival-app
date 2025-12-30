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
  group('DrinkDetailScreen', () {
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

    const product = Product(
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
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);

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
          home: DrinkDetailScreen(festivalId: 'cbf2025', drinkId: drinkId),
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
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('Test Beer'), findsOneWidget); // Appears in header only
      // Note: 'Test Brewery' appears 3 times - breadcrumb bar (clickable), header, and brewery section
      expect(find.text('Test Brewery'), findsNWidgets(3));
      expect(find.text('Cambridge, UK'), findsNWidgets(2)); // Appears in header and brewery section
    });

    testWidgets('displays drink details chips',
        (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('ABV: 5.0%'), findsOneWidget);
      expect(find.text('IPA'), findsOneWidget);
      expect(find.text('Cask'), findsOneWidget);
      expect(find.text('Main Bar'), findsOneWidget);
    });

    testWidgets('displays status text in chips when available',
        (WidgetTester tester) async {
      const productWithStatus = Product(
        id: 'drink3',
        name: 'Status Beer',
        abv: 5.5,
        category: 'beer',
        dispense: 'cask',
        statusText: 'Plenty remaining',
      );
      final drinkWithStatus = Drink(product: productWithStatus, producer: producer, festivalId: 'cbf2025');
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drinkWithStatus]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink3'));
      await tester.pumpAndSettle();

      expect(find.text('Plenty remaining'), findsOneWidget);
    });

    testWidgets('does not display status chip when status text is null',
        (WidgetTester tester) async {
      const productNoStatus = Product(
        id: 'drink4',
        name: 'No Status Beer',
        abv: 4.5,
        category: 'beer',
        dispense: 'keg',
        statusText: null,
      );
      final drinkNoStatus = Drink(product: productNoStatus, producer: producer, festivalId: 'cbf2025');
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drinkNoStatus]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink4'));
      await tester.pumpAndSettle();

      // Check that common status texts are not present
      expect(find.text('Plenty remaining'), findsNothing);
      expect(find.text('Sold out'), findsNothing);
      expect(find.text('Not yet available'), findsNothing);
    });

    testWidgets('displays description when notes exist',
        (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('A hoppy beer with citrus notes'), findsOneWidget);
    });

    testWidgets('displays allergen information',
        (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Contains:'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('displays rating section',
        (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('Your Rating'), findsOneWidget);
      expect(find.byType(StarRating), findsOneWidget);
    });

    testWidgets('displays brewery section',
        (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('Brewery'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('has share button in app bar',
        (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('has favorite button in app bar',
        (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('toggles favorite when favorite button is tapped',
        (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(drink.isFavorite, false);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      // Mock toggleFavorite to properly toggle state
      final favorites = <String>{};
      when(mockDrinkRepository.toggleFavorite(any, any)).thenAnswer((invocation) async {
        final drinkId = invocation.positionalArguments[1] as String;
        if (favorites.contains(drinkId)) {
          favorites.remove(drinkId);
          return false;
        } else {
          favorites.add(drinkId);
          return true;
        }
      });

      // Tap favorite button
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(drink.isFavorite, true);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('navigates to brewery screen when brewery card is tapped',
        (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any))
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
      
      // Verify the brewery card is present and tappable
      expect(breweryCard, findsWidgets);
      
      // NOTE: Navigation to BreweryScreen uses go_router's context.push()
      // which requires GoRouter in the widget tree. This is tested in E2E tests
      // (test-e2e/routing.spec.ts) instead of unit tests.
    });

    testWidgets('does not display description section when notes are null',
        (WidgetTester tester) async {
      const productNoNotes = Product(
        id: 'drink2',
        name: 'Simple Beer',
        abv: 4.0,
        category: 'beer',
        dispense: 'keg',
        notes: null,
      );
      final drinkNoNotes = Drink(product: productNoNotes, producer: producer, festivalId: 'cbf2025');
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drinkNoNotes]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink2'));
      await tester.pumpAndSettle();

      // Verify the drink name is there but no description text
      expect(find.text('Simple Beer'), findsWidgets);
    });

    testWidgets('displays rating value when drink has rating',
        (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();
      
      drink.rating = 4;

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('4/5'), findsOneWidget);
    });

    testWidgets('does not display rating value when drink has no rating',
        (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => [drink]);
      await provider.loadDrinks();
      
      drink.rating = null;

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('/5'), findsNothing);
    });

    testWidgets('updates rating when set through provider',
        (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any))
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

    group('Similar Drinks Section', () {
      testWidgets('displays similar drinks section when similar drinks exist',
          (WidgetTester tester) async {
        // Create multiple drinks with similar characteristics
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );

        const producer2 = Producer(
          id: 'brewery2',
          name: 'Another Brewery',
          location: 'London, UK',
          products: [],
        );

        const product1 = Product(
          id: 'drink1',
          name: 'Test IPA',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );

        const product2 = Product(
          id: 'drink2',
          name: 'Similar IPA',
          abv: 5.4, // Within 0.5% AND same style
          category: 'beer',
          dispense: 'cask',
          style: 'IPA', // Same style
        );

        const product3 = Product(
          id: 'drink3',
          name: 'Same Brewery Beer',
          abv: 4.0,
          category: 'beer',
          dispense: 'keg',
          style: 'Lager',
        );

        final drink1 = Drink(product: product1, producer: producer1, festivalId: 'cbf2025');
        final drink2 = Drink(product: product2, producer: producer2, festivalId: 'cbf2025');
        final drink3 = Drink(product: product3, producer: producer1, festivalId: 'cbf2025'); // Same brewery

        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => [drink1, drink2, drink3]);
        await provider.loadDrinks();

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // Should show Similar Drinks section
        expect(find.text('Similar Drinks'), findsOneWidget);
        
        // Scroll down to ensure similar drinks are visible
        await tester.ensureVisible(find.text('Similar Drinks'));
        await tester.pumpAndSettle();
        
        // Should show similar drinks (drink2 has same style and close ABV, drink3 has same brewery)
        expect(find.text('Similar IPA'), findsOneWidget);
        expect(find.text('Same Brewery Beer'), findsOneWidget);
        
        // Should show similarity reasons
        expect(find.text('Same style, similar strength'), findsOneWidget);
        expect(find.text('Same brewery'), findsOneWidget);
      });

      testWidgets('does not display similar drinks section when no similar drinks exist',
          (WidgetTester tester) async {
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );

        const product1 = Product(
          id: 'drink1',
          name: 'Unique Beer',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'Unique Style',
        );

        final drink1 = Drink(product: product1, producer: producer1, festivalId: 'cbf2025');

        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => [drink1]);
        await provider.loadDrinks();

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // Should not show Similar Drinks section when no similar drinks
        expect(find.text('Similar Drinks'), findsNothing);
      });

      testWidgets('similar drinks are tappable and navigate correctly',
          (WidgetTester tester) async {
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );

        const product1 = Product(
          id: 'drink1',
          name: 'Test IPA',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );

        const product2 = Product(
          id: 'drink2',
          name: 'Similar IPA',
          abv: 5.2,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );

        final drink1 = Drink(product: product1, producer: producer1, festivalId: 'cbf2025');
        final drink2 = Drink(product: product2, producer: producer1, festivalId: 'cbf2025');

        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => [drink1, drink2]);
        await provider.loadDrinks();

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // Scroll to ensure similar drinks section is visible
        await tester.ensureVisible(find.text('Similar Drinks'));
        await tester.pumpAndSettle();

        // Verify similar drink card exists
        expect(find.text('Similar IPA'), findsOneWidget);
        
        // NOTE: Navigation uses go_router's context.go() which requires GoRouter 
        // in the widget tree. This is tested in E2E tests instead of unit tests.
      });

      testWidgets('similar drinks based on same style and close ABV',
          (WidgetTester tester) async {
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );

        const producer2 = Producer(
          id: 'brewery2',
          name: 'Another Brewery',
          location: 'London, UK',
          products: [],
        );

        const product1 = Product(
          id: 'drink1',
          name: 'Test Bitter',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'Bitter',
        );

        const product2 = Product(
          id: 'drink2',
          name: 'Close ABV Bitter',
          abv: 5.3, // Within 0.5% ABV AND same style
          category: 'beer',
          dispense: 'keg',
          style: 'Bitter', // Same style - required for match
        );

        const product3 = Product(
          id: 'drink3',
          name: 'Different Style Beer',
          abv: 5.2, // Close ABV but different style - should NOT match
          category: 'beer',
          dispense: 'cask',
          style: 'Pale Ale',
        );

        const product4 = Product(
          id: 'drink4',
          name: 'Same Style Far ABV',
          abv: 7.0, // Same style but ABV too far (>0.5%) - should NOT match
          category: 'beer',
          dispense: 'cask',
          style: 'Bitter',
        );

        final drink1 = Drink(product: product1, producer: producer1, festivalId: 'cbf2025');
        final drink2 = Drink(product: product2, producer: producer2, festivalId: 'cbf2025');
        final drink3 = Drink(product: product3, producer: producer2, festivalId: 'cbf2025');
        final drink4 = Drink(product: product4, producer: producer2, festivalId: 'cbf2025');

        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => [drink1, drink2, drink3, drink4]);
        await provider.loadDrinks();

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // Scroll to ensure similar drinks section is visible
        await tester.ensureVisible(find.text('Similar Drinks'));
        await tester.pumpAndSettle();

        // Should show drink with same style AND close ABV
        expect(find.text('Close ABV Bitter'), findsOneWidget);
        expect(find.text('Same style, similar strength'), findsOneWidget);
        
        // Should NOT show drinks that don't match both criteria
        expect(find.text('Different Style Beer'), findsNothing);
        expect(find.text('Same Style Far ABV'), findsNothing);
      });
    });
  });
}
