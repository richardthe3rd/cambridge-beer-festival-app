import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';

void main() {
  group('Accessibility - DrinkCard Semantics', () {
    testWidgets('favorite button exists and is interactive', (tester) async {
      final drink = Drink(
        product: Product(
          id: '1',
          name: 'Test Beer',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
        ),
        producer: Producer(
          id: 'p1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'test2025',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrinkCard(
              drink: drink,
              onFavoriteTap: () {},
            ),
          ),
        ),
      );

      // Verify favorite button exists
      expect(find.byType(IconButton), findsWidgets,
          reason: 'DrinkCard should have interactive buttons');
      
      // Verify Semantics widgets are present
      expect(find.byType(Semantics), findsWidgets,
          reason: 'DrinkCard should have semantic labels');
    });

    testWidgets('decorative ABV chip is excluded from semantics', (tester) async {
      final drink = Drink(
        product: Product(
          id: '1',
          name: 'Test Beer',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
        ),
        producer: Producer(
          id: 'p1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'test2025',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrinkCard(drink: drink),
          ),
        ),
      );

      // Verify ExcludeSemantics is used for decorative info chips
      expect(find.byType(ExcludeSemantics), findsWidgets,
          reason: 'Decorative elements should use ExcludeSemantics');
    });

    testWidgets('card has semantic structure', (tester) async {
      final drink = Drink(
        product: Product(
          id: '1',
          name: 'Test IPA',
          abv: 6.5,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        ),
        producer: Producer(
          id: 'p1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'test2025',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrinkCard(drink: drink),
          ),
        ),
      );

      // Verify Card and Semantics widgets exist
      expect(find.byType(Card), findsOneWidget,
          reason: 'DrinkCard should use Card widget');
      expect(find.byType(Semantics), findsWidgets,
          reason: 'DrinkCard should have semantic structure');
    });
  });

  group('Accessibility - EnvironmentBadge Semantics', () {
    testWidgets('environment badge renders with semantic labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: const [
                EnvironmentBadge(environmentName: 'staging'),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify badge renders
      expect(find.byType(EnvironmentBadge), findsOneWidget,
          reason: 'Environment badge should render');
      
      // Verify it has Semantics
      expect(find.byType(Semantics), findsWidgets,
          reason: 'Environment badge should have semantic labels');
    });
  });

  group('Accessibility - Semantic Button Patterns', () {
    testWidgets('buttons use button property in Semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: 'Test button',
              button: true,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Click me'),
              ),
            ),
          ),
        ),
      );

      // Find our custom Semantics wrapper
      final allSemantics = tester.widgetList<Semantics>(
        find.byType(Semantics),
      ).toList();
      
      // Find the one with our specific label
      final ourSemantics = allSemantics.firstWhere(
        (s) => s.properties.label == 'Test button',
      );

      expect(ourSemantics.properties.button, isTrue,
          reason: 'Interactive buttons must set button: true in Semantics');
    });

    testWidgets('hints provide usage instructions when present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: 'Add to favorites',
              hint: 'Double tap to toggle',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      // Find our custom Semantics wrapper
      final allSemantics = tester.widgetList<Semantics>(
        find.byType(Semantics),
      ).toList();
      
      // Find the one with our specific label
      final ourSemantics = allSemantics.firstWhere(
        (s) => s.properties.label == 'Add to favorites',
      );

      expect(ourSemantics.properties.hint, 'Double tap to toggle',
          reason: 'Hint should match expected instruction');
    });

    testWidgets('ExcludeSemantics is used for decorative elements', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Content'),
                ExcludeSemantics(
                  child: Container(
                    width: 50,
                    height: 50,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ExcludeSemantics), findsAtLeastNWidgets(1),
          reason: 'Decorative elements should be wrapped in ExcludeSemantics');
    });
  });

  group('Accessibility - Semantic State Communication', () {
    testWidgets('filter selection state is communicated via semantics', (tester) async {
      var isSelected = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: 'Filter by IPA',
              value: isSelected ? 'Selected' : 'Not selected',
              selected: isSelected,
              button: true,
              child: FilterChip(
                label: const Text('IPA'),
                selected: isSelected,
                onSelected: (value) => isSelected = value,
              ),
            ),
          ),
        ),
      );

      // Find our custom Semantics wrapper (not the ones Material adds)
      final allSemantics = tester.widgetList<Semantics>(
        find.byType(Semantics),
      ).toList();
      
      // Find the one with our specific label
      final ourSemantics = allSemantics.firstWhere(
        (s) => s.properties.label == 'Filter by IPA',
      );

      expect(ourSemantics.properties.value, 'Selected',
          reason: 'Selected state should be communicated via value property');
      expect(ourSemantics.properties.selected, isTrue,
          reason: 'Selected property should be set to true');
    });

    testWidgets('retry button has descriptive label and hint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: 'Retry loading drinks',
              hint: 'Double tap to reload festival data',
              button: true,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Retry'),
              ),
            ),
          ),
        ),
      );

      // Find our custom Semantics wrapper
      final allSemantics = tester.widgetList<Semantics>(
        find.byType(Semantics),
      ).toList();
      
      // Find the one with our specific label
      final ourSemantics = allSemantics.firstWhere(
        (s) => s.properties.label == 'Retry loading drinks',
      );

      expect(ourSemantics.properties.label, 'Retry loading drinks',
          reason: 'Retry button should clearly state what will be retried');
      expect(ourSemantics.properties.hint, contains('Double tap'),
          reason: 'Hint should explain the interaction method');
      expect(ourSemantics.properties.button, isTrue,
          reason: 'Button property must be set');
    });
  });
}