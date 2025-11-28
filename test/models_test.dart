import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/models/models.dart';

void main() {
  group('Product', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'test-id-123',
        'name': 'Test Beer',
        'category': 'beer',
        'style': 'IPA',
        'dispense': 'cask',
        'abv': '5.5',
        'notes': 'A test beer',
        'status_text': 'Plenty left',
        'bar': 'Main Bar',
        'allergens': {'gluten': 1},
      };

      final product = Product.fromJson(json);

      expect(product.id, 'test-id-123');
      expect(product.name, 'Test Beer');
      expect(product.category, 'beer');
      expect(product.style, 'IPA');
      expect(product.dispense, 'cask');
      expect(product.abv, 5.5);
      expect(product.notes, 'A test beer');
      expect(product.statusText, 'Plenty left');
      expect(product.bar, 'Main Bar');
      expect(product.allergens, {'gluten': 1});
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'test-id',
        'name': 'Basic Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
      };

      final product = Product.fromJson(json);

      expect(product.style, isNull);
      expect(product.notes, isNull);
      expect(product.statusText, isNull);
      expect(product.bar, isNull);
      expect(product.allergens, isEmpty);
    });

    test('availabilityStatus returns correct values', () {
      expect(
        Product.fromJson({
          'id': '1', 'name': 'a', 'category': 'beer', 'dispense': 'cask', 'abv': '4',
          'status_text': 'Plenty left'
        }).availabilityStatus,
        AvailabilityStatus.plenty,
      );

      expect(
        Product.fromJson({
          'id': '2', 'name': 'b', 'category': 'beer', 'dispense': 'cask', 'abv': '4',
          'status_text': 'A little remaining'
        }).availabilityStatus,
        AvailabilityStatus.low,
      );

      expect(
        Product.fromJson({
          'id': '3', 'name': 'c', 'category': 'beer', 'dispense': 'cask', 'abv': '4',
          'status_text': 'Sold out'
        }).availabilityStatus,
        AvailabilityStatus.out,
      );
    });

    test('allergenText formats correctly', () {
      final product = Product.fromJson({
        'id': '1', 'name': 'a', 'category': 'beer', 'dispense': 'cask', 'abv': '4',
        'allergens': {'gluten': 1, 'sulphites': 1},
      });

      expect(product.allergenText, contains('Gluten'));
      expect(product.allergenText, contains('Sulphites'));
    });
  });

  group('Producer', () {
    test('fromJson parses correctly with products', () {
      final json = {
        'id': 'brewery-123',
        'name': 'Test Brewery',
        'location': 'Cambridge',
        'year_founded': 2010,
        'notes': 'A test brewery',
        'products': [
          {
            'id': 'beer-1',
            'name': 'Beer One',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '4.5',
          }
        ],
      };

      final producer = Producer.fromJson(json);

      expect(producer.id, 'brewery-123');
      expect(producer.name, 'Test Brewery');
      expect(producer.location, 'Cambridge');
      expect(producer.yearFounded, 2010);
      expect(producer.products.length, 1);
      expect(producer.products[0].name, 'Beer One');
    });

    test('fromJson handles year_founded as string', () {
      final json = {
        'id': 'brewery-456',
        'name': 'Historic Brewery',
        'location': 'Cambridge',
        'year_founded': '1890',
        'products': [],
      };

      final producer = Producer.fromJson(json);

      expect(producer.yearFounded, 1890);
    });

    test('fromJson handles missing year_founded', () {
      final json = {
        'id': 'brewery-789',
        'name': 'No Year Brewery',
        'location': 'Manchester',
        'products': [],
      };

      final producer = Producer.fromJson(json);

      expect(producer.yearFounded, isNull);
    });
  });

  group('Product allergens', () {
    test('fromJson handles allergens as boolean values', () {
      final json = {
        'id': 'beer-bool',
        'name': 'Bool Allergen Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
        'allergens': {'gluten': true, 'sulphites': false},
      };

      final product = Product.fromJson(json);

      expect(product.allergens['gluten'], 1);
      expect(product.allergens['sulphites'], 0);
    });

    test('fromJson handles allergens as numeric values', () {
      final json = {
        'id': 'beer-num',
        'name': 'Numeric Allergen Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
        'allergens': {'gluten': 1.0},
      };

      final product = Product.fromJson(json);

      expect(product.allergens['gluten'], 1);
    });
  });

  group('Festival', () {
    test('getBeverageUrl constructs correct URL', () {
      const festival = Festival(
        id: 'cbf2025',
        name: 'Cambridge Beer Festival 2025',
        dataBaseUrl: 'https://cbf-data-proxy.richard-alcock.workers.dev/cbf2025',
      );

      expect(
        festival.getBeverageUrl('beer'),
        'https://cbf-data-proxy.richard-alcock.workers.dev/cbf2025/beer.json',
      );
    });
  });
}
