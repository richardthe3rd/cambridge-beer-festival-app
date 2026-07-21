import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/domain/services/services.dart';
import 'package:cambridge_beer_festival/domain/models/models.dart';
import 'package:cambridge_beer_festival/models/models.dart';

void main() {
  group('DrinkFilterService', () {
    late DrinkFilterService service;
    late List<Drink> testDrinks;

    setUp(() {
      service = DrinkFilterService();

      // Create test data
      final producer1 = Producer.fromJson({
        'id': 'brewery-1',
        'name': 'Alpha Brewery',
        'location': 'Cambridge',
        'products': [],
      });

      final producer2 = Producer.fromJson({
        'id': 'brewery-2',
        'name': 'Beta Cidery',
        'location': 'London',
        'products': [],
      });

      final product1 = Product.fromJson({
        'id': 'drink-1',
        'name': 'Hoppy IPA',
        'category': 'beer',
        'style': 'IPA',
        'dispense': 'cask',
        'abv': '5.5',
        'notes': 'A very hoppy beer',
      });

      final product2 = Product.fromJson({
        'id': 'drink-2',
        'name': 'Smooth Bitter',
        'category': 'beer',
        'style': 'Bitter',
        'dispense': 'cask',
        'abv': '4.2',
        'notes': 'Traditional English bitter',
      });

      final product3 = Product.fromJson({
        'id': 'drink-3',
        'name': 'Dry Cider',
        'category': 'cider',
        'style': 'Dry',
        'dispense': 'bag in box',
        'abv': '6.0',
      });

      final product4 = Product.fromJson({
        'id': 'drink-4',
        'name': 'Sweet Cider',
        'category': 'cider',
        'style': 'Sweet',
        'dispense': 'keg',
        'abv': '4.5',
        'notes': 'Sweet and fruity',
        'status_text': 'Sold Out',
        'is_vegan': true,
        'allergens': {},
      });

      final product5 = Product.fromJson({
        'id': 'drink-5',
        'name': 'Coming Soon IPA',
        'category': 'beer',
        'style': 'IPA',
        'dispense': 'cask',
        'abv': '6.5',
        'status_text': 'not yet available',
      });

      testDrinks = [
        Drink(product: product1, producer: producer1, festivalId: 'test'),
        Drink(product: product2, producer: producer1, festivalId: 'test'),
        Drink(product: product3, producer: producer2, festivalId: 'test'),
        Drink(product: product4, producer: producer2, festivalId: 'test'),
        Drink(product: product5, producer: producer1, festivalId: 'test'),
      ];
    });

    group('filterByCategory', () {
      test('filters drinks by category', () {
        final result = service.filterByCategory(testDrinks, 'beer').toList();
        expect(result, hasLength(3));
        expect(result.every((d) => d.category == 'beer'), isTrue);
      });

      test('returns all drinks when category is null', () {
        final result = service.filterByCategory(testDrinks, null).toList();
        expect(result, hasLength(5));
      });

      test('returns empty list when no drinks match category', () {
        final result = service.filterByCategory(testDrinks, 'mead').toList();
        expect(result, isEmpty);
      });
    });

    group('filterByStyles', () {
      test('filters drinks by single style', () {
        final result = service.filterByStyles(testDrinks, {'IPA'}).toList();
        expect(result, hasLength(2));
        expect(result.every((d) => d.style == 'IPA'), isTrue);
      });

      test('filters drinks by multiple styles (OR logic)', () {
        final result = service.filterByStyles(testDrinks, {
          'IPA',
          'Bitter',
        }).toList();
        expect(result, hasLength(3));
        expect(
          result.every((d) => d.style == 'IPA' || d.style == 'Bitter'),
          isTrue,
        );
      });

      test('returns all drinks when styles set is empty', () {
        final result = service.filterByStyles(testDrinks, {}).toList();
        expect(result, hasLength(5));
      });

      test('returns empty list when no drinks match styles', () {
        final result = service.filterByStyles(testDrinks, {'Stout'}).toList();
        expect(result, isEmpty);
      });
    });

    group('filterByFavorites', () {
      test('filters to show only favorites', () {
        testDrinks[0] = testDrinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(wantToTry: true),
        );
        testDrinks[2] = testDrinks[2].copyWith(
          userState: UserDrinkState.initial().copyWith(wantToTry: true),
        );

        final result = service
            .filterByFavorites(testDrinks, favoritesOnly: true)
            .toList();
        expect(result, hasLength(2));
        expect(result.every((d) => d.isFavorite), isTrue);
      });

      test('returns all drinks when favoritesOnly is false', () {
        testDrinks[0] = testDrinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(wantToTry: true),
        );

        final result = service
            .filterByFavorites(testDrinks, favoritesOnly: false)
            .toList();
        expect(result, hasLength(5));
      });

      test('returns empty list when no favorites exist', () {
        final result = service
            .filterByFavorites(testDrinks, favoritesOnly: true)
            .toList();
        expect(result, isEmpty);
      });
    });

    group('filterByAvailability', () {
      test('hides drinks with status "out"', () {
        // Only AvailabilityStatus.out is hidden; unknown status texts resolve
        // to AvailabilityStatus.unknown and are not filtered out.
        final result = service
            .filterByAvailability(testDrinks, hideUnavailable: true)
            .toList();
        expect(result, hasLength(4));
        expect(
          result.every((d) => d.availabilityStatus != AvailabilityStatus.out),
          isTrue,
        );
      });

      test('includes drinks whose status_text is "not yet available"', () {
        // notYetAvailable was a dead enum value — no real festival data used it.
        // "not yet available" is not in the known vocabulary, so it resolves to
        // AvailabilityStatus.unknown and is not filtered out.
        final result = service
            .filterByAvailability(testDrinks, hideUnavailable: true)
            .toList();
        expect(result, hasLength(4));
        expect(
          result.every((d) => d.availabilityStatus != AvailabilityStatus.out),
          isTrue,
        );
      });

      test('returns all drinks when hideUnavailable is false', () {
        final result = service
            .filterByAvailability(testDrinks, hideUnavailable: false)
            .toList();
        expect(result, hasLength(5));
      });
    });

    group('filterByNotTasted', () {
      test('hides drinks already tasted', () {
        testDrinks[0] = testDrinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(
            tastingEvents: [DateTime(2026, 5, 18)],
          ),
        );
        testDrinks[1] = testDrinks[1].copyWith(
          userState: UserDrinkState.initial().copyWith(
            tastingEvents: [DateTime(2026, 5, 18)],
          ),
        );

        final result = service
            .filterByNotTasted(testDrinks, notTastedOnly: true)
            .toList();
        expect(result, hasLength(3));
        expect(result.every((d) => !d.isTasted), isTrue);
      });

      test('returns all drinks when notTastedOnly is false', () {
        testDrinks[0] = testDrinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(
            tastingEvents: [DateTime(2026, 5, 18)],
          ),
        );

        final result = service
            .filterByNotTasted(testDrinks, notTastedOnly: false)
            .toList();
        expect(result, hasLength(5));
      });
    });

    group('filterByVegan', () {
      test('shows only vegan drinks', () {
        // product4 has is_vegan: true
        final result = service
            .filterByVegan(testDrinks, veganOnly: true)
            .toList();
        expect(result, hasLength(1));
        expect(result[0].isVegan, isTrue);
      });

      test('returns all drinks when veganOnly is false', () {
        final result = service
            .filterByVegan(testDrinks, veganOnly: false)
            .toList();
        expect(result, hasLength(5));
      });
    });

    group('filterByExcludedAllergens', () {
      late Drink glutenDrink;
      late Drink sulphiteDrink;
      late Drink bothDrink;
      late Drink cleanDrink;

      setUp(() {
        final producer = testDrinks[0].producer;
        glutenDrink = Drink(
          product: Product.fromJson({
            'id': 'g',
            'name': 'Gluteny',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '4.0',
            'allergens': {'gluten': 1},
          }),
          producer: producer,
          festivalId: 'test',
        );
        sulphiteDrink = Drink(
          product: Product.fromJson({
            'id': 's',
            'name': 'Sulphitey',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '4.0',
            'allergens': {'sulphites': 1},
          }),
          producer: producer,
          festivalId: 'test',
        );
        bothDrink = Drink(
          product: Product.fromJson({
            'id': 'b',
            'name': 'Both',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '4.0',
            'allergens': {'gluten': 1, 'sulphites': 1},
          }),
          producer: producer,
          festivalId: 'test',
        );
        cleanDrink = Drink(
          product: Product.fromJson({
            'id': 'c',
            'name': 'Clean',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '4.0',
            'allergens': {},
          }),
          producer: producer,
          festivalId: 'test',
        );
      });

      test('excludes drinks that contain a selected allergen', () {
        final result = service
            .filterByExcludedAllergens([glutenDrink, cleanDrink], {'gluten'})
            .toList();
        expect(result, hasLength(1));
        expect(result[0].name, equals('Clean'));
      });

      test('passes drinks where allergen value is 0', () {
        final zeroDrink = Drink(
          product: Product.fromJson({
            'id': 'z',
            'name': 'Zero',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '4.0',
            'allergens': {'gluten': 0},
          }),
          producer: testDrinks[0].producer,
          festivalId: 'test',
        );
        final result = service
            .filterByExcludedAllergens([zeroDrink, glutenDrink], {'gluten'})
            .toList();
        expect(result, hasLength(1));
        expect(result[0].name, equals('Zero'));
      });

      test('passes drinks that lack the allergen key entirely', () {
        final noDrink = Drink(
          product: Product.fromJson({
            'id': 'n',
            'name': 'NoKey',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '4.0',
          }),
          producer: testDrinks[0].producer,
          festivalId: 'test',
        );
        final result = service
            .filterByExcludedAllergens([noDrink, glutenDrink], {'gluten'})
            .toList();
        expect(result, hasLength(1));
        expect(result[0].name, equals('NoKey'));
      });

      test('multiple excluded allergens are ANDed', () {
        final drinks = [glutenDrink, sulphiteDrink, bothDrink, cleanDrink];
        final result = service.filterByExcludedAllergens(drinks, {
          'gluten',
          'sulphites',
        }).toList();
        expect(result, hasLength(1));
        expect(result[0].name, equals('Clean'));
      });

      test('returns all drinks when excluded set is empty', () {
        final drinks = [glutenDrink, sulphiteDrink, cleanDrink];
        final result = service.filterByExcludedAllergens(drinks, {}).toList();
        expect(result, hasLength(3));
      });
    });

    group('filterBySearch', () {
      test('searches by drink name (case insensitive)', () {
        final result = service.filterBySearch(testDrinks, 'IPA').toList();
        expect(result, hasLength(2));
        expect(result.every((d) => d.name.contains('IPA')), isTrue);
      });

      test('searches by brewery name', () {
        final result = service.filterBySearch(testDrinks, 'alpha').toList();
        expect(result, hasLength(3));
        expect(result.every((d) => d.breweryName.contains('Alpha')), isTrue);
      });

      test('searches by style', () {
        final result = service.filterBySearch(testDrinks, 'bitter').toList();
        expect(result, hasLength(1));
        expect(result[0].style, equals('Bitter'));
      });

      test('searches by notes', () {
        final result = service.filterBySearch(testDrinks, 'hoppy').toList();
        expect(result, hasLength(1));
        expect(result[0].notes, contains('hoppy'));
      });

      test("searches the user's own note content (case insensitive)", () {
        final noted = testDrinks[1].copyWith(
          userState: UserDrinkState(
            notes: 'Dave said try this',
            createdAt: DateTime(2025, 6, 10),
            updatedAt: DateTime(2025, 6, 10),
          ),
        );
        final drinks = [testDrinks[0], noted, testDrinks[2]];

        final result = service.filterBySearch(drinks, 'dave').toList();

        expect(result, hasLength(1));
        expect(result[0].id, noted.id);
      });

      test('filterDrinks search also matches user notes', () {
        final noted = testDrinks[1].copyWith(
          userState: UserDrinkState(
            notes: 'Dave said try this',
            createdAt: DateTime(2025, 6, 10),
            updatedAt: DateTime(2025, 6, 10),
          ),
        );

        final result = service.filterDrinks([
          testDrinks[0],
          noted,
          testDrinks[2],
        ], searchQuery: 'Dave');

        expect(result, hasLength(1));
        expect(result[0].id, noted.id);
      });

      test('returns all drinks when query is empty', () {
        final result = service.filterBySearch(testDrinks, '').toList();
        expect(result, hasLength(5));
      });

      test('returns empty list when no matches found', () {
        final result = service
            .filterBySearch(testDrinks, 'nonexistent')
            .toList();
        expect(result, isEmpty);
      });

      test('searches across multiple fields', () {
        final result = service.filterBySearch(testDrinks, 'sweet').toList();
        expect(
          result,
          hasLength(1),
        ); // "Sweet Cider" has sweet in name and notes
      });
    });

    group('filterDrinks', () {
      test('applies all filters in combination', () {
        testDrinks[0] = testDrinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(wantToTry: true),
        ); // Hoppy IPA

        final result = service.filterDrinks(
          testDrinks,
          category: 'beer',
          styles: {'IPA'},
          favoritesOnly: true,
          visibilityFilters: {DrinkVisibilityFilter.availableOnly},
          searchQuery: 'hoppy',
        );

        expect(result, hasLength(1));
        expect(result[0].name, equals('Hoppy IPA'));
      });

      test('applies no filters when all criteria are default', () {
        final result = service.filterDrinks(testDrinks);
        expect(result, hasLength(5));
      });

      test('applies only category filter', () {
        final result = service.filterDrinks(testDrinks, category: 'cider');
        expect(result, hasLength(2));
        expect(result.every((d) => d.category == 'cider'), isTrue);
      });

      test('applies category and style filters together', () {
        final result = service.filterDrinks(
          testDrinks,
          category: 'beer',
          styles: {'IPA'},
        );
        expect(result, hasLength(2));
        expect(
          result.every((d) => d.category == 'beer' && d.style == 'IPA'),
          isTrue,
        );
      });

      test('filters are applied in sequence (order matters)', () {
        // First filter by category (beer = 3 drinks).
        // The "Coming Soon IPA" has status_text 'not yet available', which
        // resolves to unknown — it is NOT filtered out by availableOnly
        // (only AvailabilityStatus.out is excluded).
        final result = service.filterDrinks(
          testDrinks,
          category: 'beer',
          visibilityFilters: {DrinkVisibilityFilter.availableOnly},
        );
        expect(result, hasLength(3));
      });

      test('returns empty list when filters exclude all drinks', () {
        final result = service.filterDrinks(
          testDrinks,
          category: 'mead', // No meads in test data
        );
        expect(result, isEmpty);
      });

      test('applies excludedAllergens via filterDrinks', () {
        final producer = testDrinks[0].producer;
        final glutenDrink = Drink(
          product: Product.fromJson({
            'id': 'gx',
            'name': 'Gluteny',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '4.0',
            'allergens': {'gluten': 1},
          }),
          producer: producer,
          festivalId: 'test',
        );
        final cleanDrink = Drink(
          product: Product.fromJson({
            'id': 'cx',
            'name': 'Clean',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '4.0',
            'allergens': {},
          }),
          producer: producer,
          festivalId: 'test',
        );

        final result = service.filterDrinks(
          [glutenDrink, cleanDrink],
          excludedAllergens: {'gluten'},
        );
        expect(result, hasLength(1));
        expect(result[0].name, equals('Clean'));
      });
    });
  });
}
