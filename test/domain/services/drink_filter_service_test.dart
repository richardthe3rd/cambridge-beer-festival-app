import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/domain/services/services.dart';
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
        'status_text': 'out',
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
        final result = service.filterByStyles(testDrinks, {'IPA', 'Bitter'}).toList();
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
        testDrinks[0].isFavorite = true;
        testDrinks[2].isFavorite = true;

        final result = service.filterByFavorites(testDrinks, true).toList();
        expect(result, hasLength(2));
        expect(result.every((d) => d.isFavorite), isTrue);
      });

      test('returns all drinks when favoritesOnly is false', () {
        testDrinks[0].isFavorite = true;

        final result = service.filterByFavorites(testDrinks, false).toList();
        expect(result, hasLength(5));
      });

      test('returns empty list when no favorites exist', () {
        final result = service.filterByFavorites(testDrinks, true).toList();
        expect(result, isEmpty);
      });
    });

    group('filterByAvailability', () {
      test('hides drinks with status "out"', () {
        final result = service.filterByAvailability(testDrinks, true).toList();
        expect(result, hasLength(3));
        expect(
          result.every((d) => d.availabilityStatus != AvailabilityStatus.out),
          isTrue,
        );
      });

      test('hides drinks with status "not yet available"', () {
        final result = service.filterByAvailability(testDrinks, true).toList();
        expect(result, hasLength(3));
        expect(
          result.every((d) =>
              d.availabilityStatus != AvailabilityStatus.notYetAvailable),
          isTrue,
        );
      });

      test('returns all drinks when hideUnavailable is false', () {
        final result = service.filterByAvailability(testDrinks, false).toList();
        expect(result, hasLength(5));
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

      test('returns all drinks when query is empty', () {
        final result = service.filterBySearch(testDrinks, '').toList();
        expect(result, hasLength(5));
      });

      test('returns empty list when no matches found', () {
        final result = service.filterBySearch(testDrinks, 'nonexistent').toList();
        expect(result, isEmpty);
      });

      test('searches across multiple fields', () {
        final result = service.filterBySearch(testDrinks, 'sweet').toList();
        expect(result, hasLength(1)); // "Sweet Cider" has sweet in name and notes
      });
    });

    group('filterDrinks', () {
      test('applies all filters in combination', () {
        testDrinks[0].isFavorite = true; // Hoppy IPA

        final result = service.filterDrinks(
          testDrinks,
          category: 'beer',
          styles: {'IPA'},
          favoritesOnly: true,
          hideUnavailable: true,
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
        final result = service.filterDrinks(
          testDrinks,
          category: 'cider',
        );
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
        // First filter by category (beer = 3 drinks)
        // Then filter by availability (removes "Coming Soon IPA" = 2 drinks)
        final result = service.filterDrinks(
          testDrinks,
          category: 'beer',
          hideUnavailable: true,
        );
        expect(result, hasLength(2));
      });

      test('returns empty list when filters exclude all drinks', () {
        final result = service.filterDrinks(
          testDrinks,
          category: 'mead', // No meads in test data
        );
        expect(result, isEmpty);
      });
    });
  });
}
