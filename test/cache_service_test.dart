import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Drink makeDrink(
    String producerId,
    String productId, {
    String name = 'Test Drink',
    Map<String, int> allergens = const {},
    bool? isVegan,
  }) =>
      Drink(
        product: Product(
          id: productId,
          name: name,
          category: 'beer',
          style: 'IPA',
          dispense: 'cask',
          abv: 5.5,
          allergens: allergens,
          isVegan: isVegan,
        ),
        producer: Producer(
          id: producerId,
          name: 'Producer $producerId',
          location: 'Cambridge',
          yearFounded: 1990,
          products: const [],
        ),
        festivalId: 'cbf2025',
      );

  group('DrinkCacheService', () {
    late DrinkCacheService cache;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      cache = DrinkCacheService(prefs);
    });

    test('returns null when nothing is cached', () {
      expect(cache.read('cbf2025'), isNull);
    });

    test('round-trips drinks across multiple producers', () async {
      final drinks = [
        makeDrink('b1', 'p1', name: 'Alpha'),
        makeDrink('b1', 'p2', name: 'Beta'),
        makeDrink('b2', 'p3', name: 'Gamma'),
      ];

      await cache.save('cbf2025', drinks);
      final read = cache.read('cbf2025');

      expect(read, isNotNull);
      expect(read!.length, 3);
      final byId = {for (final d in read) d.id: d};
      expect(byId['p1']!.name, 'Alpha');
      expect(byId['p1']!.producer.id, 'b1');
      expect(byId['p3']!.producer.id, 'b2');
      expect(byId['p1']!.abv, 5.5);
      expect(byId['p1']!.style, 'IPA');
    });

    test('preserves allergens, vegan flag and unicode names', () async {
      final drinks = [
        makeDrink(
          'b1',
          'p1',
          name: 'Rosé Cider',
          allergens: const {'gluten': 1, 'sulphites': 0},
          isVegan: true,
        ),
      ];

      await cache.save('cbf2025', drinks);
      final read = cache.read('cbf2025')!;

      expect(read.single.name, 'Rosé Cider');
      expect(read.single.allergens['gluten'], 1);
      expect(read.single.isVegan, isTrue);
      expect(read.single.producer.yearFounded, 1990);
    });

    test('is scoped per festival', () async {
      await cache.save('cbf2025', [makeDrink('b1', 'p1')]);

      expect(cache.read('cbf2025'), isNotNull);
      expect(cache.read('cbf2024'), isNull);
    });

    test('returns null for an empty drink list', () async {
      await cache.save('cbf2025', []);
      expect(cache.read('cbf2025'), isNull);
    });

    test('returns null for corrupt cached data', () async {
      SharedPreferences.setMockInitialValues({
        'drinks_cache_cbf2025': 'not valid json {',
      });
      final prefs = await SharedPreferences.getInstance();
      final corruptCache = DrinkCacheService(prefs);

      expect(corruptCache.read('cbf2025'), isNull);
    });

    test('clear removes cached drinks', () async {
      await cache.save('cbf2025', [makeDrink('b1', 'p1')]);
      await cache.clear('cbf2025');

      expect(cache.read('cbf2025'), isNull);
    });
  });

  group('FestivalCacheService', () {
    late FestivalCacheService cache;

    FestivalsResponse makeResponse() => FestivalsResponse.fromJson(
          {
            'festivals': [
              {
                'id': 'cbf2025',
                'name': 'Cambridge Beer Festival 2025',
                'data_base_url': 'https://example.com/cbf2025',
                'is_active': true,
                'available_beverage_types': ['beer', 'cider'],
              },
              {
                'id': 'cbf2024',
                'name': 'Cambridge Beer Festival 2024',
                'data_base_url': 'https://example.com/cbf2024',
              },
            ],
            'default_festival_id': 'cbf2025',
            'version': '2.0.0',
          },
          'https://example.com',
        );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      cache = FestivalCacheService(prefs);
    });

    test('returns null when nothing is cached', () {
      expect(cache.read(), isNull);
    });

    test('round-trips the festivals response', () async {
      await cache.save(makeResponse());
      final read = cache.read();

      expect(read, isNotNull);
      expect(read!.festivals.length, 2);
      expect(read.defaultFestivalId, 'cbf2025');
      expect(read.version, '2.0.0');

      final cbf2025 = read.festivals.firstWhere((f) => f.id == 'cbf2025');
      expect(cbf2025.dataBaseUrl, 'https://example.com/cbf2025');
      expect(cbf2025.isActive, isTrue);
      expect(cbf2025.availableBeverageTypes, ['beer', 'cider']);
      expect(read.defaultFestival?.id, 'cbf2025');
    });

    test('returns null for corrupt cached data', () async {
      SharedPreferences.setMockInitialValues({
        'festivals_cache': '}{ broken',
      });
      final prefs = await SharedPreferences.getInstance();
      final corruptCache = FestivalCacheService(prefs);

      expect(corruptCache.read(), isNull);
    });

    test('clear removes the cached response', () async {
      await cache.save(makeResponse());
      await cache.clear();

      expect(cache.read(), isNull);
    });
  });
}
