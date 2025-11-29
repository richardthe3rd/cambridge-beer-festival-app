import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/widgets/drink_card.dart';
import 'package:cambridge_beer_festival/models/models.dart';

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

    testWidgets('displays brewery name and location', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('Test Brewery • Cambridge'), findsOneWidget);
    });

    testWidgets('displays brewery name only when location is empty', 
        (WidgetTester tester) async {
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

    testWidgets('displays availability status when present', 
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('shows favorite icon as outlined when not favorite', 
        (WidgetTester tester) async {
      testDrink.isFavorite = false;
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    testWidgets('shows favorite icon as filled when favorite', 
        (WidgetTester tester) async {
      testDrink.isFavorite = true;
      await tester.pumpWidget(createTestWidget(drink: testDrink));

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('calls onTap when card is tapped', 
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(createTestWidget(
        drink: testDrink,
        onTap: () => tapped = true,
      ));

      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('calls onFavoriteTap when favorite icon is tapped', 
        (WidgetTester tester) async {
      bool favoriteTapped = false;
      await tester.pumpWidget(createTestWidget(
        drink: testDrink,
        onFavoriteTap: () => favoriteTapped = true,
      ));

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(favoriteTapped, isTrue);
    });

    testWidgets('does not show style chip when style is null', 
        (WidgetTester tester) async {
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

    testWidgets('shows low availability chip correctly', 
        (WidgetTester tester) async {
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

    testWidgets('shows sold out chip correctly', 
        (WidgetTester tester) async {
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

    testWidgets('handles drink without availability status', 
        (WidgetTester tester) async {
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

    testWidgets('formats dispense method with capital first letter', 
        (WidgetTester tester) async {
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
}
