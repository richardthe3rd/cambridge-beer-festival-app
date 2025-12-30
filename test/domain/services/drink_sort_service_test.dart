import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/domain/services/services.dart';
import 'package:cambridge_beer_festival/domain/models/models.dart';
import 'package:cambridge_beer_festival/models/models.dart';

void main() {
  group('DrinkSortService', () {
    late DrinkSortService service;
    late List<Drink> testDrinks;

    setUp(() {
      service = DrinkSortService();

      // Create test data with varying attributes for sorting
      final producer1 = Producer.fromJson({
        'id': 'brewery-1',
        'name': 'Zeta Brewery',
        'location': 'Cambridge',
        'products': [],
      });

      final producer2 = Producer.fromJson({
        'id': 'brewery-2',
        'name': 'Alpha Brewery',
        'location': 'London',
        'products': [],
      });

      final product1 = Product.fromJson({
        'id': 'drink-1',
        'name': 'Charlie Beer',
        'category': 'beer',
        'style': 'IPA',
        'dispense': 'cask',
        'abv': '5.5',
      });

      final product2 = Product.fromJson({
        'id': 'drink-2',
        'name': 'Alpha Ale',
        'category': 'beer',
        'style': 'Bitter',
        'dispense': 'cask',
        'abv': '4.2',
      });

      final product3 = Product.fromJson({
        'id': 'drink-3',
        'name': 'Bravo Bitter',
        'category': 'beer',
        'style': 'Bitter',
        'dispense': 'cask',
        'abv': '3.8',
      });

      final product4 = Product.fromJson({
        'id': 'drink-4',
        'name': 'Delta Strong',
        'category': 'beer',
        'style': 'Stout',
        'dispense': 'keg',
        'abv': '7.2',
      });

      final product5 = Product.fromJson({
        'id': 'drink-5',
        'name': 'Echo Lager',
        'category': 'beer',
        // No style
        'dispense': 'keg',
        'abv': '4.5',
      });

      testDrinks = [
        Drink(product: product1, producer: producer1, festivalId: 'test'),
        Drink(product: product2, producer: producer2, festivalId: 'test'),
        Drink(product: product3, producer: producer1, festivalId: 'test'),
        Drink(product: product4, producer: producer2, festivalId: 'test'),
        Drink(product: product5, producer: producer1, festivalId: 'test'),
      ];
    });

    group('sortByNameAsc', () {
      test('sorts drinks by name A-Z', () {
        final result = service.sortDrinks(List.from(testDrinks), DrinkSort.nameAsc);
        expect(result[0].name, equals('Alpha Ale'));
        expect(result[1].name, equals('Bravo Bitter'));
        expect(result[2].name, equals('Charlie Beer'));
        expect(result[3].name, equals('Delta Strong'));
        expect(result[4].name, equals('Echo Lager'));
      });

      test('returns new list without modifying original', () {
        final drinks = List<Drink>.from(testDrinks);
        final originalOrder = drinks.map((d) => d.name).toList();
        final result = service.sortDrinks(drinks, DrinkSort.nameAsc);

        // Result should be a different list
        expect(identical(result, drinks), isFalse);

        // Original should be unchanged
        expect(drinks.map((d) => d.name).toList(), equals(originalOrder));

        // Result should be sorted
        expect(result[0].name, equals('Alpha Ale'));
      });
    });

    group('sortByNameDesc', () {
      test('sorts drinks by name Z-A', () {
        final result = service.sortDrinks(List.from(testDrinks), DrinkSort.nameDesc);
        expect(result[0].name, equals('Echo Lager'));
        expect(result[1].name, equals('Delta Strong'));
        expect(result[2].name, equals('Charlie Beer'));
        expect(result[3].name, equals('Bravo Bitter'));
        expect(result[4].name, equals('Alpha Ale'));
      });
    });

    group('sortByAbvHigh', () {
      test('sorts drinks by ABV highest to lowest', () {
        final result = service.sortDrinks(List.from(testDrinks), DrinkSort.abvHigh);
        expect(result[0].abv, equals(7.2)); // Delta Strong
        expect(result[1].abv, equals(5.5)); // Charlie Beer
        expect(result[2].abv, equals(4.5)); // Echo Lager
        expect(result[3].abv, equals(4.2)); // Alpha Ale
        expect(result[4].abv, equals(3.8)); // Bravo Bitter
      });
    });

    group('sortByAbvLow', () {
      test('sorts drinks by ABV lowest to highest', () {
        final result = service.sortDrinks(List.from(testDrinks), DrinkSort.abvLow);
        expect(result[0].abv, equals(3.8)); // Bravo Bitter
        expect(result[1].abv, equals(4.2)); // Alpha Ale
        expect(result[2].abv, equals(4.5)); // Echo Lager
        expect(result[3].abv, equals(5.5)); // Charlie Beer
        expect(result[4].abv, equals(7.2)); // Delta Strong
      });
    });

    group('sortByBrewery', () {
      test('sorts drinks by brewery name alphabetically', () {
        final result = service.sortDrinks(List.from(testDrinks), DrinkSort.brewery);
        // Alpha Brewery comes before Zeta Brewery
        expect(result[0].breweryName, equals('Alpha Brewery'));
        expect(result[1].breweryName, equals('Alpha Brewery'));
        expect(result[2].breweryName, equals('Zeta Brewery'));
        expect(result[3].breweryName, equals('Zeta Brewery'));
        expect(result[4].breweryName, equals('Zeta Brewery'));
      });
    });

    group('sortByStyle', () {
      test('sorts drinks by style alphabetically', () {
        final result = service.sortDrinks(List.from(testDrinks), DrinkSort.style);
        // Empty string (no style) comes first, then Bitter, IPA, Stout
        expect(result[0].style, isNull); // Echo Lager
        expect(result[1].style, equals('Bitter'));
        expect(result[2].style, equals('Bitter'));
        expect(result[3].style, equals('IPA'));
        expect(result[4].style, equals('Stout'));
      });

      test('handles drinks without style', () {
        final result = service.sortDrinks(List.from(testDrinks), DrinkSort.style);
        // Drinks without style should be sorted to the beginning
        expect(result[0].name, equals('Echo Lager'));
      });
    });

    group('sortDrinks', () {
      test('sorts by nameAsc when given DrinkSort.nameAsc', () {
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.nameAsc,
        );
        expect(result[0].name, equals('Alpha Ale'));
        expect(result[4].name, equals('Echo Lager'));
      });

      test('sorts by nameDesc when given DrinkSort.nameDesc', () {
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.nameDesc,
        );
        expect(result[0].name, equals('Echo Lager'));
        expect(result[4].name, equals('Alpha Ale'));
      });

      test('sorts by abvHigh when given DrinkSort.abvHigh', () {
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.abvHigh,
        );
        expect(result[0].abv, equals(7.2));
        expect(result[4].abv, equals(3.8));
      });

      test('sorts by abvLow when given DrinkSort.abvLow', () {
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.abvLow,
        );
        expect(result[0].abv, equals(3.8));
        expect(result[4].abv, equals(7.2));
      });

      test('sorts by brewery when given DrinkSort.brewery', () {
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.brewery,
        );
        expect(result[0].breweryName, equals('Alpha Brewery'));
        expect(result[1].breweryName, equals('Alpha Brewery'));
      });

      test('sorts by style when given DrinkSort.style', () {
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.style,
        );
        expect(result[0].style, isNull);
        expect(result[1].style, equals('Bitter'));
      });

      test('handles all DrinkSort enum values', () {
        // Ensure all enum values work without error
        for (final sort in DrinkSort.values) {
          expect(
            () => service.sortDrinks(List.from(testDrinks), sort),
            returnsNormally,
          );
        }
      });
    });
  });
}
