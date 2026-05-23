import 'dart:convert';

import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Drink makeDrink(
    String producerId,
    String productId, {
    String name = 'Test Drink',
    String category = 'beer',
    Map<String, int> allergens = const {},
    bool? isVegan,
  }) =>
      Drink(
        product: Product(
          id: productId,
          name: name,
          category: category,
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

    Future<void> store(String festivalId, Map<String, List<Drink>> byType) =>
        cache.merge(festivalId, byType).written;

    test('returns null when nothing is cached', () {
      expect(cache.read('cbf2025'), isNull);
    });

    test('merge returns the merged drinks synchronously', () {
      final update = cache.merge('cbf2025', {
        'beer': [makeDrink('b1', 'p1'), makeDrink('b2', 'p2')],
      });

      expect(update.drinks.map((d) => d.id), containsAll(['p1', 'p2']));
    });

    test('round-trips drinks across multiple producers', () async {
      await store('cbf2025', {
        'beer': [
          makeDrink('b1', 'p1', name: 'Alpha'),
          makeDrink('b1', 'p2', name: 'Beta'),
          makeDrink('b2', 'p3', name: 'Gamma'),
        ],
      });
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
      await store('cbf2025', {
        'cider': [
          makeDrink(
            'b1',
            'p1',
            name: 'Rosé Cider',
            category: 'cider',
            allergens: const {'gluten': 1, 'sulphites': 0},
            isVegan: true,
          ),
        ],
      });
      final read = cache.read('cbf2025')!;

      expect(read.single.name, 'Rosé Cider');
      expect(read.single.allergens['gluten'], 1);
      expect(read.single.isVegan, isTrue);
      expect(read.single.producer.yearFounded, 1990);
    });

    test('merge preserves beverage types that are not refreshed', () async {
      await store('cbf2025', {
        'beer': [makeDrink('b1', 'beer-1', category: 'beer')],
        'cider': [makeDrink('c1', 'cider-1', category: 'cider')],
      });

      // Refresh only beer; cider should be retained from the previous snapshot.
      await store('cbf2025', {
        'beer': [makeDrink('b1', 'beer-2', category: 'beer')],
      });

      final read = cache.read('cbf2025')!;
      final ids = read.map((d) => d.id).toSet();
      expect(ids, containsAll(['beer-2', 'cider-1']));
      expect(ids.contains('beer-1'), isFalse);
    });

    test('is scoped per festival', () async {
      await store('cbf2025', {
        'beer': [makeDrink('b1', 'p1')],
      });

      expect(cache.read('cbf2025'), isNotNull);
      expect(cache.read('cbf2024'), isNull);
    });

    test('returns null for an empty drink list', () async {
      await store('cbf2025', {'beer': []});
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

    test('drops a beverage type whose producers value is not a list', () async {
      // Decodable JSON but the per-type payload is malformed (e.g. a partial
      // migration left a string where a producers list belongs). Reading must
      // degrade to the well-formed entries instead of throwing.
      final goodProducer = {
        'id': 'b1',
        'name': 'Producer b1',
        'location': 'Cambridge',
        'products': [
          {
            'id': 'p1',
            'name': 'Good',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '5.5',
          },
        ],
      };
      SharedPreferences.setMockInitialValues({
        'drinks_cache_cbf2025': json.encode({
          'timestamp': 1,
          'beverageTypes': {
            'beer': [goodProducer],
            'cider': 'oops not a list',
          },
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final corruptCache = DrinkCacheService(prefs);

      final read = corruptCache.read('cbf2025');
      expect(read, isNotNull);
      expect(read!.single.id, 'p1');
    });

    test('clear removes cached drinks', () async {
      await store('cbf2025', {
        'beer': [makeDrink('b1', 'p1')],
      });
      await cache.clear('cbf2025');

      expect(cache.read('cbf2025'), isNull);
    });

    test('evicts the oldest festival snapshots beyond the cap', () async {
      // Cap is 12; create 13 festival snapshots, the oldest should be dropped.
      for (var i = 0; i < 13; i++) {
        await store('cbf$i', {
          'beer': [makeDrink('b$i', 'p$i')],
        });
      }

      expect(cache.read('cbf0'), isNull); // oldest evicted
      expect(cache.read('cbf12'), isNotNull); // newest retained
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
