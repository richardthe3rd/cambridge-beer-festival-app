import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:cambridge_beer_festival/widgets/drink_card.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/domain/models/drink_visibility_filter.dart';
import 'provider_test.mocks.dart';

void main() {
  late Drink testDrink;
  late Producer testProducer;
  late Product testProduct;

  setUp(() {
    testProducer = Producer.fromJson({
      'id': 'brewery-1',
      'name': 'Test Brewery',
      'location': 'Cambridge',
      'products': [],
    });

    testProduct = Product.fromJson({
      'id': 'drink-1',
      'name': 'Test IPA',
      'category': 'beer',
      'style': 'IPA',
      'dispense': 'cask',
      'abv': '5.5',
      'status_text': 'Plenty left',
    });

    testDrink = Drink(
      product: testProduct,
      producer: testProducer,
      festivalId: 'cbf2025',
    );
  });

  Widget createTestWidget({
    required Drink drink,
    VoidCallback? onTap,
    VoidCallback? onFavoriteTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DrinkCard(
          drink: drink,
          onTap: onTap,
          onFavoriteTap: onFavoriteTap,
        ),
      ),
    );
  }

  group('DrinkCard', () {
    testWidgets('displays drink name', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('Test IPA'), findsOneWidget);
    });

    testWidgets('displays brewery name and location', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('Test Brewery • Cambridge'), findsOneWidget);
    });

    testWidgets('displays brewery name only when location is empty', (
      WidgetTester tester,
    ) async {
      final producerNoLocation = Producer.fromJson({
        'id': 'brewery-2',
        'name': 'Another Brewery',
        'location': '',
        'products': [],
      });

      final drink = Drink(
        product: testProduct,
        producer: producerNoLocation,
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.text('Another Brewery'), findsOneWidget);
      expect(find.text('Another Brewery • '), findsNothing);
    });

    testWidgets('displays ABV percentage', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('5.5%'), findsOneWidget);
    });

    testWidgets('displays style when available', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('IPA'), findsOneWidget);
    });

    testWidgets('displays dispense method', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('Cask'), findsOneWidget);
    });

    testWidgets('displays availability status when present', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('shows favorite icon as outlined when not favorite', (
      WidgetTester tester,
    ) async {
      testDrink = testDrink.copyWith(userState: null);
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    testWidgets('shows favorite icon as filled when favorite', (
      WidgetTester tester,
    ) async {
      testDrink = testDrink.copyWith(
        userState: UserDrinkState.initial().copyWith(wantToTry: true),
      );
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('calls onTap when card is tapped', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        createTestWidget(drink: testDrink, onTap: () => tapped = true),
      );

      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('calls onFavoriteTap when favorite icon is tapped', (
      WidgetTester tester,
    ) async {
      bool favoriteTapped = false;
      await tester.pumpWidget(
        createTestWidget(
          drink: testDrink,
          onFavoriteTap: () => favoriteTapped = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(favoriteTapped, isTrue);
    });

    testWidgets('does not show style chip when style is null', (
      WidgetTester tester,
    ) async {
      final productNoStyle = Product.fromJson({
        'id': 'drink-2',
        'name': 'Basic Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
      });

      final drink = Drink(
        product: productNoStyle,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createTestWidget(drink: drink));

      // Should still show ABV and dispense but not style
      expect(find.text('4.0%'), findsOneWidget);
      expect(find.text('Cask'), findsOneWidget);
    });

    testWidgets('shows low availability chip correctly', (
      WidgetTester tester,
    ) async {
      final productLow = Product.fromJson({
        'id': 'drink-3',
        'name': 'Low Stock Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
        'status_text': 'A little remaining',
      });

      final drink = Drink(
        product: productLow,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.text('Low'), findsOneWidget);
    });

    testWidgets('shows sold out chip correctly', (WidgetTester tester) async {
      final productOut = Product.fromJson({
        'id': 'drink-4',
        'name': 'Gone Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
        'status_text': 'Sold out',
      });

      final drink = Drink(
        product: productOut,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.text('Sold Out'), findsOneWidget);
    });

    testWidgets('handles drink without availability status', (
      WidgetTester tester,
    ) async {
      final productNoStatus = Product.fromJson({
        'id': 'drink-5',
        'name': 'No Status Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
      });

      final drink = Drink(
        product: productNoStatus,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createTestWidget(drink: drink));

      // Should render without availability chip
      expect(find.text('Available'), findsNothing);
      expect(find.text('Low'), findsNothing);
      expect(find.text('Sold Out'), findsNothing);
    });

    testWidgets('formats dispense method with capital first letter', (
      WidgetTester tester,
    ) async {
      final productKeg = Product.fromJson({
        'id': 'drink-6',
        'name': 'Keg Beer',
        'category': 'beer',
        'dispense': 'keg',
        'abv': '5.0',
      });

      final drink = Drink(
        product: productKeg,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createTestWidget(drink: drink));

      expect(find.text('Keg'), findsOneWidget);
      expect(find.text('keg'), findsNothing);
    });
  });

  group('DrinkCard accent bar', () {
    Drink drinkWithCategory(String category) {
      final product = Product.fromJson({
        'id': 'drink-accent',
        'name': 'Accent Test',
        'category': category,
        'dispense': 'cask',
        'abv': '4.0',
      });
      return Drink(
        product: product,
        producer: testProducer,
        festivalId: 'cbf2025',
      );
    }

    Color? accentBorderColor(WidgetTester tester) {
      for (final c in tester.widgetList<Container>(find.byType(Container))) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          final border = decoration.border;
          if (border is Border) {
            final left = border.left;
            if (left.width == 4) return left.color;
          }
        }
      }
      return null;
    }

    testWidgets('cider uses green accent', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('cider')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFF22C55E)));
    });

    testWidgets('perry uses lime accent', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('perry')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFF84CC16)));
    });

    testWidgets('mead uses gold accent', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('mead')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFFD97706)));
    });

    testWidgets('wine uses purple accent', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('wine')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFF9333EA)));
    });

    testWidgets('international-beer uses red accent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('international-beer')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFFEF4444)));
    });

    testWidgets('low-no uses cyan accent', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('low-no')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFF06B6D4)));
    });

    testWidgets('apple-juice uses apple-green accent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('apple-juice')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFF65A30D)));
    });

    testWidgets('unknown category uses navy fallback accent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(drink: drinkWithCategory('unknown-type')),
      );
      expect(accentBorderColor(tester), equals(const Color(0xFF2B3170)));
    });
  });

  group('DrinkCard chip interactions', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;
    late Drink testDrink;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.setFestival(
        const Festival(
          id: 'cbf2025',
          name: 'Cambridge Beer Festival 2025',
          dataBaseUrl: 'https://example.com',
        ),
      );

      testDrink = Drink(
        product: const Product(
          id: 'drink-1',
          name: 'Test IPA',
          abv: 5.5,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        ),
        producer: const Producer(
          id: 'brewery-1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'cbf2025',
      );
    });

    Widget createProviderTestWidget({required Drink drink}) {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(body: DrinkCard(drink: drink)),
        ),
      );
    }

    testWidgets('tapping category chip sets provider category', (tester) async {
      await tester.pumpWidget(createProviderTestWidget(drink: testDrink));

      // Find and tap the category chip (shows 'Beer' label)
      await tester.tap(find.text('Beer'));
      await tester.pumpAndSettle();

      expect(provider.selectedCategory, equals('beer'));
    });

    testWidgets(
      'tapping availability chip enables availableOnly filter for non-plenty status',
      (tester) async {
        final soldOutDrink = Drink(
          product: const Product(
            id: 'drink-out',
            name: 'Sold Out Beer',
            abv: 4.0,
            category: 'beer',
            dispense: 'cask',
            statusText: 'Sold out',
          ),
          producer: const Producer(
            id: 'brewery-1',
            name: 'Test Brewery',
            location: 'Cambridge',
            products: [],
          ),
          festivalId: 'cbf2025',
        );

        await tester.pumpWidget(createProviderTestWidget(drink: soldOutDrink));

        // Tap the 'Sold Out' availability chip
        await tester.tap(find.text('Sold Out'));
        await tester.pumpAndSettle();

        expect(
          provider.visibilityFilters.contains(
            DrinkVisibilityFilter.availableOnly,
          ),
          isTrue,
        );
      },
    );

    testWidgets('tapping availability chip is no-op when status is plenty', (
      tester,
    ) async {
      await tester.pumpWidget(createProviderTestWidget(drink: testDrink));
      // testDrink has no statusText, so availabilityStatus is null — show a drink with 'Plenty left'
      final plentyDrink = Drink(
        product: const Product(
          id: 'drink-plenty',
          name: 'Plenty Beer',
          abv: 4.0,
          category: 'beer',
          dispense: 'cask',
          statusText: 'Plenty left',
        ),
        producer: const Producer(
          id: 'brewery-1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'cbf2025',
      );

      await tester.pumpWidget(createProviderTestWidget(drink: plentyDrink));

      await tester.tap(find.text('Available'));
      await tester.pumpAndSettle();

      expect(
        provider.visibilityFilters.contains(
          DrinkVisibilityFilter.availableOnly,
        ),
        isFalse,
      );
    });
  });
}
