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
        'products': <Map<String, dynamic>>[],
      });

      final producer2 = Producer.fromJson({
        'id': 'brewery-2',
        'name': 'Alpha Brewery',
        'location': 'London',
        'products': <Map<String, dynamic>>[],
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
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.nameAsc,
        );
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
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.nameDesc,
        );
        expect(result[0].name, equals('Echo Lager'));
        expect(result[1].name, equals('Delta Strong'));
        expect(result[2].name, equals('Charlie Beer'));
        expect(result[3].name, equals('Bravo Bitter'));
        expect(result[4].name, equals('Alpha Ale'));
      });
    });

    group('sortByAbvHigh', () {
      test('sorts drinks by ABV highest to lowest', () {
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.abvHigh,
        );
        expect(result[0].abv, equals(7.2)); // Delta Strong
        expect(result[1].abv, equals(5.5)); // Charlie Beer
        expect(result[2].abv, equals(4.5)); // Echo Lager
        expect(result[3].abv, equals(4.2)); // Alpha Ale
        expect(result[4].abv, equals(3.8)); // Bravo Bitter
      });
    });

    group('sortByAbvLow', () {
      test('sorts drinks by ABV lowest to highest', () {
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.abvLow,
        );
        expect(result[0].abv, equals(3.8)); // Bravo Bitter
        expect(result[1].abv, equals(4.2)); // Alpha Ale
        expect(result[2].abv, equals(4.5)); // Echo Lager
        expect(result[3].abv, equals(5.5)); // Charlie Beer
        expect(result[4].abv, equals(7.2)); // Delta Strong
      });
    });

    // A null ABV means the feed never said how strong the drink is (#593); it
    // is not a point on the scale. Both directions therefore park it at the
    // end — in particular "lowest first" must not open with a run of drinks of
    // unknown strength, which is what treating null as 0.0 produced.
    group('drinks of unknown ABV', () {
      Drink unknownAbvDrink(String id, String name) {
        final producer = Producer.fromJson(<String, dynamic>{
          'id': 'brewery-unknown',
          'name': 'Mystery Brewery',
          'location': 'Cambridge',
          'products': <Map<String, dynamic>>[],
        });
        // No 'abv' key at all — the shape a feed omission actually produces.
        final product = Product.fromJson(<String, dynamic>{
          'id': id,
          'name': name,
          'category': 'beer',
          'dispense': 'cask',
        });
        return Drink(
          product: product,
          producer: producer,
          festivalId: 'test-festival',
        );
      }

      test('sort last when ABV is highest first', () {
        final drinks = <Drink>[
          unknownAbvDrink('unknown-1', 'Mystery Ale'),
          ...testDrinks,
        ];

        final result = service.sortDrinks(drinks, DrinkSort.abvHigh);

        expect(result.first.abv, equals(7.2));
        expect(result.last.abv, isNull);
        expect(result.last.name, equals('Mystery Ale'));
      });

      test('sort last when ABV is lowest first, not first as a 0.0 would', () {
        final drinks = <Drink>[
          unknownAbvDrink('unknown-1', 'Mystery Ale'),
          ...testDrinks,
        ];

        final result = service.sortDrinks(drinks, DrinkSort.abvLow);

        // The weakest *known* drink leads, not the unknown one.
        expect(result.first.abv, equals(3.8));
        expect(result.first.name, equals('Bravo Bitter'));
        expect(result.last.abv, isNull);
      });

      test('a genuinely alcohol-free drink still sorts as the weakest', () {
        final alcoholFree = Drink(
          product: Product.fromJson(<String, dynamic>{
            'id': 'low-no-1',
            'name': 'Zero Lager',
            'category': 'low-no',
            'dispense': 'keg',
            'abv': '0.0',
          }),
          producer: Producer.fromJson(<String, dynamic>{
            'id': 'brewery-3',
            'name': 'Sober Brewery',
            'location': 'Ely',
            'products': <Map<String, dynamic>>[],
          }),
          festivalId: 'test-festival',
        );
        final drinks = <Drink>[
          unknownAbvDrink('unknown-1', 'Mystery Ale'),
          alcoholFree,
          ...testDrinks,
        ];

        final result = service.sortDrinks(drinks, DrinkSort.abvLow);

        expect(result.first.name, equals('Zero Lager'));
        expect(result.first.abv, equals(0.0));
        expect(result.last.name, equals('Mystery Ale'));
      });

      // Which argument the comparator sees an unknown in depends on where it
      // sat in the input, so drive every position: the "known first, unknown
      // second" branch is otherwise never exercised and the nulls-last
      // guarantee only holds by accident of the sort's call order.
      test('unknowns trail regardless of their position in the input', () {
        for (var position = 0; position <= testDrinks.length; position++) {
          final drinks = <Drink>[...testDrinks]
            ..insert(position, unknownAbvDrink('unknown-1', 'Mystery Ale'));

          for (final sort in <DrinkSort>[DrinkSort.abvHigh, DrinkSort.abvLow]) {
            final result = service.sortDrinks(drinks, sort);
            expect(
              result.last.abv,
              isNull,
              reason: 'unknown inserted at $position should trail for $sort',
            );
            expect(
              result.take(result.length - 1).map((d) => d.abv),
              everyElement(isNotNull),
              reason: 'only the unknown should trail for $sort',
            );
          }
        }
      });

      test('several unknowns stay together at the end of both directions', () {
        final drinks = <Drink>[
          unknownAbvDrink('unknown-1', 'Mystery Ale'),
          ...testDrinks,
          unknownAbvDrink('unknown-2', 'Mystery Stout'),
        ];

        for (final sort in <DrinkSort>[DrinkSort.abvHigh, DrinkSort.abvLow]) {
          final result = service.sortDrinks(drinks, sort);
          expect(
            result.sublist(result.length - 2).map((d) => d.abv),
            everyElement(isNull),
            reason: 'unknown ABVs should trail the list for $sort',
          );
          expect(
            result.sublist(0, result.length - 2).map((d) => d.abv),
            everyElement(isNotNull),
            reason: 'known ABVs should all precede unknowns for $sort',
          );
        }
      });
    });

    group('sortByBrewery', () {
      test('sorts drinks by brewery name alphabetically', () {
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.brewery,
        );
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
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.style,
        );
        // Empty string (no style) comes first, then Bitter, IPA, Stout
        expect(result[0].style, isNull); // Echo Lager
        expect(result[1].style, equals('Bitter'));
        expect(result[2].style, equals('Bitter'));
        expect(result[3].style, equals('IPA'));
        expect(result[4].style, equals('Stout'));
      });

      test('handles drinks without style', () {
        final result = service.sortDrinks(
          List.from(testDrinks),
          DrinkSort.style,
        );
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

    group('case-insensitive ordering', () {
      // A raw String.compareTo puts every capitalised name before every
      // lowercase one, so a brewery like "d'Achouffe" (real, in the cbf2026
      // feed) lands at the bottom of the list instead of between "Cydefx" and
      // "Daleside". The style facet already sorts case-insensitively via
      // StringComparisonHelper, so the two lists disagreed.
      Drink drinkFrom({
        required String id,
        required String name,
        required String breweryName,
        String? style,
      }) => Drink(
        product: Product(
          id: id,
          name: name,
          category: 'beer',
          style: style,
          dispense: 'cask',
          abv: 5,
        ),
        producer: Producer(
          id: 'producer-$id',
          name: breweryName,
          location: 'Cambridge',
          products: const [],
        ),
        festivalId: 'cbf2026',
      );

      test('sorts breweries case-insensitively', () {
        final drinks = [
          drinkFrom(id: 'a', name: 'A', breweryName: 'Zotler'),
          drinkFrom(id: 'b', name: 'B', breweryName: "d'Achouffe"),
          drinkFrom(id: 'c', name: 'C', breweryName: 'Cydefx'),
          drinkFrom(id: 'd', name: 'D', breweryName: 'Daleside'),
        ];

        final result = service.sortDrinks(drinks, DrinkSort.brewery);

        expect(
          result.map((d) => d.breweryName).toList(),
          ['Cydefx', "d'Achouffe", 'Daleside', 'Zotler'],
          reason:
              "d'Achouffe belongs between Cydefx and Daleside, not after Zotler",
        );
      });

      test('sorts names case-insensitively in both directions', () {
        final drinks = [
          drinkFrom(id: 'a', name: 'Zebra Stout', breweryName: 'X'),
          drinkFrom(id: 'b', name: 'abbot Ale', breweryName: 'Y'),
          drinkFrom(id: 'c', name: 'Bishop Bitter', breweryName: 'Z'),
        ];

        expect(
          service
              .sortDrinks(drinks, DrinkSort.nameAsc)
              .map((d) => d.name)
              .toList(),
          ['abbot Ale', 'Bishop Bitter', 'Zebra Stout'],
        );
        expect(
          service
              .sortDrinks(drinks, DrinkSort.nameDesc)
              .map((d) => d.name)
              .toList(),
          ['Zebra Stout', 'Bishop Bitter', 'abbot Ale'],
        );
      });

      test('sorts styles case-insensitively, nulls first', () {
        final drinks = [
          drinkFrom(id: 'a', name: 'A', breweryName: 'X', style: 'Stout'),
          drinkFrom(
            id: 'b',
            name: 'B',
            breweryName: 'Y',
            style: 'american ipa',
          ),
          drinkFrom(id: 'c', name: 'C', breweryName: 'Z'),
        ];

        expect(
          service
              .sortDrinks(drinks, DrinkSort.style)
              .map((d) => d.style)
              .toList(),
          [null, 'american ipa', 'Stout'],
        );
      });
    });
  });
}
