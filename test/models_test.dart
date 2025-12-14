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

      expect(
        Product.fromJson({
          'id': '4', 'name': 'd', 'category': 'beer', 'dispense': 'cask', 'abv': '4',
          'status_text': 'Not yet available'
        }).availabilityStatus,
        AvailabilityStatus.notYetAvailable,
      );

      expect(
        Product.fromJson({
          'id': '5', 'name': 'e', 'category': 'beer', 'dispense': 'cask', 'abv': '4',
          'status_text': 'Coming soon'
        }).availabilityStatus,
        AvailabilityStatus.notYetAvailable,
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

    group('ABV parsing', () {
      test('parses ABV as int', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': 5,
        });
        expect(product.abv, 5.0);
      });

      test('parses ABV as double', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': 5.5,
        });
        expect(product.abv, 5.5);
      });

      test('handles null ABV as 0.0', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': null,
        });
        expect(product.abv, 0.0);
      });

      test('handles invalid ABV string as 0.0', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': 'not-a-number',
        });
        expect(product.abv, 0.0);
      });
    });

    group('bar field parsing', () {
      test('parses bar as string', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4.0',
          'bar': 'Main Bar',
        });
        expect(product.bar, 'Main Bar');
      });

      test('parses bar as int', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4.0',
          'bar': 1,
        });
        expect(product.bar, '1');
      });

      test('handles bar as boolean (returns null)', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4.0',
          'bar': true,
        });
        expect(product.bar, isNull);
      });
    });

    group('availability status edge cases', () {
      test('returns plenty for "arrived" status', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4',
          'status_text': 'Just arrived',
        });
        expect(product.availabilityStatus, AvailabilityStatus.plenty);
      });

      test('returns plenty for "available" status', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4',
          'status_text': 'Now available',
        });
        expect(product.availabilityStatus, AvailabilityStatus.plenty);
      });

      test('returns low for "nearly" status', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4',
          'status_text': 'Nearly gone',
        });
        expect(product.availabilityStatus, AvailabilityStatus.low);
      });

      test('returns low for "low" status', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4',
          'status_text': 'Running low',
        });
        expect(product.availabilityStatus, AvailabilityStatus.low);
      });

      test('returns null for null status_text', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4',
        });
        expect(product.availabilityStatus, isNull);
      });

      test('returns plenty for unknown status', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4',
          'status_text': 'Unknown status',
        });
        expect(product.availabilityStatus, AvailabilityStatus.plenty);
      });
    });

    group('allergenText edge cases', () {
      test('returns null for empty allergens map', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4',
          'allergens': <String, dynamic>{},
        });
        expect(product.allergenText, isNull);
      });

      test('returns null when all allergen values are 0', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4',
          'allergens': {'gluten': 0, 'sulphites': 0},
        });
        expect(product.allergenText, isNull);
      });

      test('filters out allergens with value 0', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4',
          'allergens': {'gluten': 1, 'sulphites': 0, 'wheat': 1},
        });
        expect(product.allergenText, contains('Gluten'));
        expect(product.allergenText, contains('Wheat'));
        expect(product.allergenText, isNot(contains('Sulphites')));
      });
    });

    group('toJson', () {
      test('converts product to JSON correctly', () {
        const product = Product(
          id: 'test-id',
          name: 'Test Beer',
          category: 'beer',
          style: 'IPA',
          dispense: 'cask',
          abv: 5.5,
          notes: 'A test beer',
          statusText: 'Plenty left',
          bar: 'Main Bar',
          allergens: {'gluten': 1},
        );

        final json = product.toJson();

        expect(json['id'], 'test-id');
        expect(json['name'], 'Test Beer');
        expect(json['category'], 'beer');
        expect(json['style'], 'IPA');
        expect(json['dispense'], 'cask');
        expect(json['abv'], '5.5');
        expect(json['notes'], 'A test beer');
        expect(json['status_text'], 'Plenty left');
        expect(json['bar'], 'Main Bar');
        expect(json['allergens'], {'gluten': 1});
      });

      test('excludes null optional fields from JSON', () {
        const product = Product(
          id: 'test-id',
          name: 'Test Beer',
          category: 'beer',
          dispense: 'cask',
          abv: 4.0,
        );

        final json = product.toJson();

        expect(json.containsKey('style'), isFalse);
        expect(json.containsKey('notes'), isFalse);
        expect(json.containsKey('status_text'), isFalse);
        expect(json.containsKey('bar'), isFalse);
      });
    });

    group('default values', () {
      test('uses default category when missing', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'dispense': 'cask',
          'abv': '4',
        });
        expect(product.category, 'beer');
      });

      test('uses default dispense when missing', () {
        final product = Product.fromJson({
          'id': '1',
          'name': 'a',
          'category': 'beer',
          'abv': '4',
        });
        expect(product.dispense, 'cask');
      });
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

    test('fromJson handles invalid year_founded string', () {
      final json = {
        'id': 'brewery-invalid',
        'name': 'Invalid Year Brewery',
        'location': 'London',
        'year_founded': 'not-a-year',
        'products': [],
      };

      final producer = Producer.fromJson(json);

      expect(producer.yearFounded, isNull);
    });

    test('fromJson handles null products list', () {
      final json = {
        'id': 'brewery-null',
        'name': 'Null Products Brewery',
        'location': 'Oxford',
        'products': null,
      };

      final producer = Producer.fromJson(json);

      expect(producer.products, isEmpty);
    });

    test('fromJson handles missing products list', () {
      final json = {
        'id': 'brewery-missing',
        'name': 'Missing Products Brewery',
        'location': 'Bristol',
      };

      final producer = Producer.fromJson(json);

      expect(producer.products, isEmpty);
    });

    test('fromJson handles missing location', () {
      final json = {
        'id': 'brewery-no-loc',
        'name': 'No Location Brewery',
        'products': [],
      };

      final producer = Producer.fromJson(json);

      expect(producer.location, '');
    });

    group('toJson', () {
      test('converts producer to JSON correctly', () {
        const product = Product(
          id: 'beer-1',
          name: 'Beer One',
          category: 'beer',
          dispense: 'cask',
          abv: 4.5,
        );

        const producer = Producer(
          id: 'brewery-123',
          name: 'Test Brewery',
          location: 'Cambridge',
          yearFounded: 2010,
          notes: 'A test brewery',
          products: [product],
        );

        final json = producer.toJson();

        expect(json['id'], 'brewery-123');
        expect(json['name'], 'Test Brewery');
        expect(json['location'], 'Cambridge');
        expect(json['year_founded'], 2010);
        expect(json['notes'], 'A test brewery');
        expect(json['products'], isList);
        expect((json['products'] as List).length, 1);
      });

      test('excludes null optional fields from JSON', () {
        const producer = Producer(
          id: 'brewery-456',
          name: 'Simple Brewery',
          location: 'Manchester',
          products: [],
        );

        final json = producer.toJson();

        expect(json.containsKey('year_founded'), isFalse);
        expect(json.containsKey('notes'), isFalse);
      });
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

    test('fromJson handles null allergens map', () {
      final json = {
        'id': 'beer-null-allergens',
        'name': 'Null Allergens Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
        'allergens': null,
      };

      final product = Product.fromJson(json);

      expect(product.allergens, isEmpty);
    });

    test('fromJson skips allergens with invalid values', () {
      final json = {
        'id': 'beer-invalid',
        'name': 'Invalid Allergen Beer',
        'category': 'beer',
        'dispense': 'cask',
        'abv': '4.0',
        'allergens': {'gluten': 1, 'invalid': 'string', 'wheat': null},
      };

      final product = Product.fromJson(json);

      expect(product.allergens['gluten'], 1);
      expect(product.allergens.containsKey('invalid'), isFalse);
      expect(product.allergens.containsKey('wheat'), isFalse);
    });
  });

  group('Drink', () {
    final testProduct = Product.fromJson({
      'id': 'prod-123',
      'name': 'Test IPA',
      'category': 'beer',
      'style': 'IPA',
      'dispense': 'cask',
      'abv': '6.5',
      'notes': 'Hoppy and bold',
      'status_text': 'Plenty left',
      'bar': 'Bar A',
      'allergens': {'gluten': 1},
    });

    final testProducer = Producer.fromJson({
      'id': 'brew-456',
      'name': 'Test Brewery',
      'location': 'Cambridge',
      'year_founded': 2015,
      'products': [],
    });

    test('creates drink with product and producer', () {
      final drink = Drink(
        product: testProduct,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      expect(drink.id, 'prod-123');
      expect(drink.name, 'Test IPA');
      expect(drink.breweryName, 'Test Brewery');
      expect(drink.breweryLocation, 'Cambridge');
      expect(drink.festivalId, 'cbf2025');
    });

    test('delegates getters to product correctly', () {
      final drink = Drink(
        product: testProduct,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      expect(drink.category, 'beer');
      expect(drink.style, 'IPA');
      expect(drink.dispense, 'cask');
      expect(drink.abv, 6.5);
      expect(drink.notes, 'Hoppy and bold');
      expect(drink.statusText, 'Plenty left');
      expect(drink.bar, 'Bar A');
      expect(drink.allergens, {'gluten': 1});
      expect(drink.availabilityStatus, AvailabilityStatus.plenty);
      expect(drink.allergenText, 'Gluten');
    });

    test('default isFavorite is false', () {
      final drink = Drink(
        product: testProduct,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      expect(drink.isFavorite, isFalse);
    });

    test('default rating is null', () {
      final drink = Drink(
        product: testProduct,
        producer: testProducer,
        festivalId: 'cbf2025',
      );

      expect(drink.rating, isNull);
    });

    test('can set isFavorite', () {
      final drink = Drink(
        product: testProduct,
        producer: testProducer,
        festivalId: 'cbf2025',
        isFavorite: true,
      );

      expect(drink.isFavorite, isTrue);

      drink.isFavorite = false;
      expect(drink.isFavorite, isFalse);
    });

    test('can set rating', () {
      final drink = Drink(
        product: testProduct,
        producer: testProducer,
        festivalId: 'cbf2025',
        rating: 4,
      );

      expect(drink.rating, 4);

      drink.rating = 5;
      expect(drink.rating, 5);
    });

    group('getShareMessage', () {
      test('generates message without rating', () {
        final drink = Drink(
          product: testProduct,
          producer: testProducer,
          festivalId: 'cbf2025',
        );

        final message = drink.getShareMessage('#cbf2025');

        expect(message, 'Drinking Test IPA from Test Brewery at #cbf2025');
      });

      test('generates message with rating', () {
        final drink = Drink(
          product: testProduct,
          producer: testProducer,
          festivalId: 'cbf2025',
          rating: 4,
        );

        final message = drink.getShareMessage('#cbf2025');

        expect(message, 'Drinking Test IPA from Test Brewery at #cbf2025 - 4 stars');
      });

      test('uses provided hashtag', () {
        final drink = Drink(
          product: testProduct,
          producer: testProducer,
          festivalId: 'cbfw2025',
        );

        final message = drink.getShareMessage('#cbfw2025');

        expect(message, 'Drinking Test IPA from Test Brewery at #cbfw2025');
      });
    });
  });

  group('Festival', () {
    test('getBeverageUrl constructs correct URL', () {
      const festival = Festival(
        id: 'cbf2025',
        name: 'Cambridge Beer Festival 2025',
        dataBaseUrl: 'https://data.cambeerfestival.app/cbf2025',
      );

      expect(
        festival.getBeverageUrl('beer'),
        'https://data.cambeerfestival.app/cbf2025/beer.json',
      );
    });

    test('getBeverageUrl works for different beverage types', () {
      const festival = Festival(
        id: 'cbf2025',
        name: 'Cambridge Beer Festival 2025',
        dataBaseUrl: 'https://example.com/cbf2025',
      );

      expect(festival.getBeverageUrl('cider'), 'https://example.com/cbf2025/cider.json');
      expect(festival.getBeverageUrl('mead'), 'https://example.com/cbf2025/mead.json');
      expect(festival.getBeverageUrl('wine'), 'https://example.com/cbf2025/wine.json');
    });

    group('formattedDates', () {
      test('returns empty string when startDate is null', () {
        const festival = Festival(
          id: 'cbf2025',
          name: 'Cambridge Beer Festival 2025',
          dataBaseUrl: 'https://example.com/cbf2025',
        );

        expect(festival.formattedDates, '');
      });

      test('formats single date when endDate is null', () {
        final festival = Festival(
          id: 'cbf2025',
          name: 'Cambridge Beer Festival 2025',
          startDate: DateTime(2025, 5, 19),
          dataBaseUrl: 'https://example.com/cbf2025',
        );

        expect(festival.formattedDates, 'May 19, 2025');
      });

      test('formats date range in same month', () {
        final festival = Festival(
          id: 'cbf2025',
          name: 'Cambridge Beer Festival 2025',
          startDate: DateTime(2025, 5, 19),
          endDate: DateTime(2025, 5, 24),
          dataBaseUrl: 'https://example.com/cbf2025',
        );

        expect(festival.formattedDates, 'May 19-24, 2025');
      });

      test('formats date range across months', () {
        final festival = Festival(
          id: 'cbf2025',
          name: 'Cambridge Beer Festival 2025',
          startDate: DateTime(2025, 5, 28),
          endDate: DateTime(2025, 6, 2),
          dataBaseUrl: 'https://example.com/cbf2025',
        );

        expect(festival.formattedDates, 'May 28 - Jun 2, 2025');
      });

      test('formats all months correctly', () {
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];

        for (var i = 0; i < 12; i++) {
          final festival = Festival(
            id: 'test',
            name: 'Test',
            startDate: DateTime(2025, i + 1, 1),
            dataBaseUrl: 'https://example.com/test',
          );
          expect(festival.formattedDates, contains(months[i]));
        }
      });
    });

    group('fromJson', () {
      test('parses complete festival JSON', () {
        final json = {
          'id': 'cbf2025',
          'name': 'Cambridge Beer Festival 2025',
          'hashtag': '#cbf2025',
          'start_date': '2025-05-19T00:00:00.000Z',
          'end_date': '2025-05-24T00:00:00.000Z',
          'location': 'Jesus Green, Cambridge',
          'address': 'Jesus Green, Cambridge CB5 8AB',
          'latitude': 52.2127,
          'longitude': 0.1234,
          'description': 'The best beer festival',
          'website_url': 'https://example.com',
          'hours': {'Monday': '12:00 - 22:00', 'Tuesday': '11:00 - 22:00'},
          'available_beverage_types': ['beer', 'cider', 'mead'],
          'data_base_url': 'https://example.com/cbf2025',
          'is_active': true,
        };

        final festival = Festival.fromJson(json);

        expect(festival.id, 'cbf2025');
        expect(festival.name, 'Cambridge Beer Festival 2025');
        expect(festival.hashtag, '#cbf2025');
        expect(festival.startDate, isNotNull);
        expect(festival.endDate, isNotNull);
        expect(festival.location, 'Jesus Green, Cambridge');
        expect(festival.address, 'Jesus Green, Cambridge CB5 8AB');
        expect(festival.latitude, 52.2127);
        expect(festival.longitude, 0.1234);
        expect(festival.description, 'The best beer festival');
        expect(festival.websiteUrl, 'https://example.com');
        expect(festival.hours, isNotNull);
        expect(festival.hours!['Monday'], '12:00 - 22:00');
        expect(festival.availableBeverageTypes, ['beer', 'cider', 'mead']);
        expect(festival.dataBaseUrl, 'https://example.com/cbf2025');
        expect(festival.isActive, isTrue);
      });

      test('parses minimal festival JSON', () {
        final json = {
          'id': 'test',
          'name': 'Test Festival',
          'data_base_url': 'https://example.com/test',
        };

        final festival = Festival.fromJson(json);

        expect(festival.id, 'test');
        expect(festival.name, 'Test Festival');
        expect(festival.hashtag, isNull);
        expect(festival.startDate, isNull);
        expect(festival.endDate, isNull);
        expect(festival.location, isNull);
        expect(festival.address, isNull);
        expect(festival.latitude, isNull);
        expect(festival.longitude, isNull);
        expect(festival.description, isNull);
        expect(festival.websiteUrl, isNull);
        expect(festival.hours, isNull);
        expect(festival.availableBeverageTypes, ['beer']);
        expect(festival.isActive, isFalse);
      });

      test('handles latitude and longitude as int', () {
        final json = {
          'id': 'test',
          'name': 'Test Festival',
          'data_base_url': 'https://example.com/test',
          'latitude': 52,
          'longitude': 0,
        };

        final festival = Festival.fromJson(json);

        expect(festival.latitude, 52.0);
        expect(festival.longitude, 0.0);
      });
    });

    group('toJson', () {
      test('converts festival to JSON correctly', () {
        final festival = Festival(
          id: 'cbf2025',
          name: 'Cambridge Beer Festival 2025',
          hashtag: '#cbf2025',
          startDate: DateTime(2025, 5, 19),
          endDate: DateTime(2025, 5, 24),
          location: 'Jesus Green',
          address: 'Cambridge',
          latitude: 52.2127,
          longitude: 0.1234,
          description: 'Great festival',
          websiteUrl: 'https://example.com',
          hours: {'Monday': '12:00 - 22:00'},
          availableBeverageTypes: ['beer', 'cider'],
          dataBaseUrl: 'https://example.com/cbf2025',
          isActive: true,
        );

        final json = festival.toJson();

        expect(json['id'], 'cbf2025');
        expect(json['name'], 'Cambridge Beer Festival 2025');
        expect(json['hashtag'], '#cbf2025');
        expect(json['start_date'], isNotNull);
        expect(json['end_date'], isNotNull);
        expect(json['location'], 'Jesus Green');
        expect(json['address'], 'Cambridge');
        expect(json['latitude'], 52.2127);
        expect(json['longitude'], 0.1234);
        expect(json['description'], 'Great festival');
        expect(json['website_url'], 'https://example.com');
        expect(json['hours'], {'Monday': '12:00 - 22:00'});
        expect(json['available_beverage_types'], ['beer', 'cider']);
        expect(json['data_base_url'], 'https://example.com/cbf2025');
        expect(json['is_active'], isTrue);
      });

      test('excludes null optional fields from JSON', () {
        const festival = Festival(
          id: 'test',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com/test',
        );

        final json = festival.toJson();

        expect(json.containsKey('hashtag'), isFalse);
        expect(json.containsKey('start_date'), isFalse);
        expect(json.containsKey('end_date'), isFalse);
        expect(json.containsKey('location'), isFalse);
        expect(json.containsKey('address'), isFalse);
        expect(json.containsKey('latitude'), isFalse);
        expect(json.containsKey('longitude'), isFalse);
        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('website_url'), isFalse);
        expect(json.containsKey('hours'), isFalse);
      });
    });

    group('DefaultFestivals', () {
      test('cambridge2025 is configured correctly', () {
        final festival = DefaultFestivals.cambridge2025;

        expect(festival.id, 'cbf2025');
        expect(festival.name, 'Cambridge Beer Festival 2025');
        expect(festival.isActive, isTrue);
        expect(festival.availableBeverageTypes, contains('beer'));
        expect(festival.availableBeverageTypes, contains('cider'));
        expect(festival.availableBeverageTypes, contains('mead'));
      });

      test('cambridgeWinter2025 is configured correctly', () {
        final festival = DefaultFestivals.cambridgeWinter2025;

        expect(festival.id, 'cbfw2025');
        expect(festival.name, 'Cambridge Winter Beer Festival 2025');
        expect(festival.isActive, isFalse);
        expect(festival.availableBeverageTypes, contains('beer'));
      });

      test('cambridge2024 is configured correctly', () {
        final festival = DefaultFestivals.cambridge2024;

        expect(festival.id, 'cbf2024');
        expect(festival.name, 'Cambridge Beer Festival 2024');
        expect(festival.isActive, isFalse);
        expect(festival.availableBeverageTypes, contains('beer'));
        expect(festival.availableBeverageTypes, contains('cider'));
        expect(festival.availableBeverageTypes, contains('mead'));
      });

      test('all returns list of festivals', () {
        final festivals = DefaultFestivals.all;

        expect(festivals.length, 3);
        expect(festivals.map((f) => f.id), contains('cbf2025'));
        expect(festivals.map((f) => f.id), contains('cbfw2025'));
        expect(festivals.map((f) => f.id), contains('cbf2024'));
      });
    });

    group('FestivalStatus', () {
      test('isLive returns true when current date is between start and end', () {
        final festival = Festival(
          id: 'test',
          name: 'Test Festival',
          startDate: DateTime(2025, 5, 19),
          endDate: DateTime(2025, 5, 24),
          dataBaseUrl: 'https://example.com/test',
        );

        // During the festival
        expect(festival.isLive(DateTime(2025, 5, 20)), isTrue);
        expect(festival.isLive(DateTime(2025, 5, 19)), isTrue);
        expect(festival.isLive(DateTime(2025, 5, 24, 23, 59)), isTrue);
        
        // Before the festival
        expect(festival.isLive(DateTime(2025, 5, 18)), isFalse);
        
        // After the festival
        expect(festival.isLive(DateTime(2025, 5, 25)), isFalse);
      });

      test('isUpcoming returns true when start date is in the future', () {
        final festival = Festival(
          id: 'test',
          name: 'Test Festival',
          startDate: DateTime(2025, 5, 19),
          endDate: DateTime(2025, 5, 24),
          dataBaseUrl: 'https://example.com/test',
        );

        expect(festival.isUpcoming(DateTime(2025, 5, 18)), isTrue);
        expect(festival.isUpcoming(DateTime(2025, 1, 1)), isTrue);
        expect(festival.isUpcoming(DateTime(2025, 5, 19)), isFalse);
        expect(festival.isUpcoming(DateTime(2025, 5, 25)), isFalse);
      });

      test('hasEnded returns true when end date has passed', () {
        final festival = Festival(
          id: 'test',
          name: 'Test Festival',
          startDate: DateTime(2025, 5, 19),
          endDate: DateTime(2025, 5, 24),
          dataBaseUrl: 'https://example.com/test',
        );

        expect(festival.hasEnded(DateTime(2025, 5, 25)), isTrue);
        expect(festival.hasEnded(DateTime(2025, 6, 1)), isTrue);
        expect(festival.hasEnded(DateTime(2025, 5, 24, 23, 59)), isFalse);
        expect(festival.hasEnded(DateTime(2025, 5, 20)), isFalse);
      });

      test('getBasicStatus returns correct status', () {
        final festival = Festival(
          id: 'test',
          name: 'Test Festival',
          startDate: DateTime(2025, 5, 19),
          endDate: DateTime(2025, 5, 24),
          dataBaseUrl: 'https://example.com/test',
        );

        expect(festival.getBasicStatus(DateTime(2025, 5, 1)), FestivalStatus.upcoming);
        expect(festival.getBasicStatus(DateTime(2025, 5, 20)), FestivalStatus.live);
        expect(festival.getBasicStatus(DateTime(2025, 6, 1)), FestivalStatus.past);
      });

      test('sortByDate orders festivals correctly', () {
        final live = Festival(
          id: 'live',
          name: 'Live Festival',
          startDate: DateTime(2025, 5, 19),
          endDate: DateTime(2025, 5, 24),
          dataBaseUrl: 'https://example.com/live',
        );
        
        final upcoming1 = Festival(
          id: 'upcoming1',
          name: 'Upcoming Festival 1',
          startDate: DateTime(2025, 6, 1),
          endDate: DateTime(2025, 6, 5),
          dataBaseUrl: 'https://example.com/upcoming1',
        );
        
        final upcoming2 = Festival(
          id: 'upcoming2',
          name: 'Upcoming Festival 2',
          startDate: DateTime(2025, 7, 1),
          endDate: DateTime(2025, 7, 5),
          dataBaseUrl: 'https://example.com/upcoming2',
        );
        
        final past1 = Festival(
          id: 'past1',
          name: 'Past Festival 1',
          startDate: DateTime(2025, 4, 1),
          endDate: DateTime(2025, 4, 5),
          dataBaseUrl: 'https://example.com/past1',
        );
        
        final past2 = Festival(
          id: 'past2',
          name: 'Past Festival 2',
          startDate: DateTime(2025, 3, 1),
          endDate: DateTime(2025, 3, 5),
          dataBaseUrl: 'https://example.com/past2',
        );

        // Test with date during live festival
        final now = DateTime(2025, 5, 20);
        final sorted = Festival.sortByDate([past2, upcoming2, past1, live, upcoming1], now);

        expect(sorted[0].id, 'live'); // Live first
        expect(sorted[1].id, 'upcoming1'); // Then upcoming (soonest first)
        expect(sorted[2].id, 'upcoming2');
        expect(sorted[3].id, 'past1'); // Then past (most recent first)
        expect(sorted[4].id, 'past2');
      });

      test('getStatusInContext identifies most recent festival', () {
        final past1 = Festival(
          id: 'past1',
          name: 'Past Festival 1',
          startDate: DateTime(2025, 4, 1),
          endDate: DateTime(2025, 4, 5),
          dataBaseUrl: 'https://example.com/past1',
        );
        
        final past2 = Festival(
          id: 'past2',
          name: 'Past Festival 2',
          startDate: DateTime(2025, 3, 1),
          endDate: DateTime(2025, 3, 5),
          dataBaseUrl: 'https://example.com/past2',
        );

        final now = DateTime(2025, 5, 1);
        final sorted = Festival.sortByDate([past2, past1], now);

        expect(Festival.getStatusInContext(past1, sorted, now), FestivalStatus.mostRecent);
        expect(Festival.getStatusInContext(past2, sorted, now), FestivalStatus.past);
      });
    });
  });

  group('AvailabilityStatus', () {
    test('enum has correct values', () {
      expect(AvailabilityStatus.values.length, 4);
      expect(AvailabilityStatus.values, contains(AvailabilityStatus.plenty));
      expect(AvailabilityStatus.values, contains(AvailabilityStatus.low));
      expect(AvailabilityStatus.values, contains(AvailabilityStatus.out));
      expect(AvailabilityStatus.values, contains(AvailabilityStatus.notYetAvailable));
    });
  });
}
