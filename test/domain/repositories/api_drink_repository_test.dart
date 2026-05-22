import 'package:cambridge_beer_festival/domain/repositories/repositories.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_drink_repository_test.mocks.dart';

@GenerateNiceMocks([MockSpec<BeerApiService>()])
void main() {
  const festival = Festival(
    id: 'cbf2025',
    name: 'Cambridge Beer Festival 2025',
    dataBaseUrl: 'https://example.com/cbf2025',
  );

  Drink makeDrink(String id) => Drink(
        product: Product(
          id: id,
          name: 'Drink $id',
          category: 'beer',
          dispense: 'cask',
          abv: 4.0,
        ),
        producer: const Producer(
          id: 'brewery-1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: festival.id,
      );

  group('ApiDrinkRepository', () {
    late MockBeerApiService apiService;
    late FavoritesService favoritesService;
    late RatingsService ratingsService;
    late TastingLogService tastingLogService;
    late DrinkCacheService cacheService;
    late ApiDrinkRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      apiService = MockBeerApiService();
      favoritesService = FavoritesService(prefs);
      ratingsService = RatingsService(prefs);
      tastingLogService = TastingLogService(prefs);
      cacheService = DrinkCacheService(prefs);
      repository = ApiDrinkRepository(
        apiService: apiService,
        favoritesService: favoritesService,
        ratingsService: ratingsService,
        tastingLogService: tastingLogService,
        cacheService: cacheService,
      );
    });

    FestivalDrinksResult ok(List<Drink> drinks, {String type = 'beer'}) =>
        FestivalDrinksResult(
          drinksByType: {type: drinks},
          failedTypes: const {},
        );

    group('getDrinks', () {
      test('populates favourite, rating and tasted state in one pass',
          () async {
        when(apiService.fetchDrinksByType(festival)).thenAnswer(
          (_) async => ok([makeDrink('d1'), makeDrink('d2'), makeDrink('d3')]),
        );
        await favoritesService.addFavorite(festival.id, 'd1');
        await ratingsService.setRating(festival.id, 'd2', 4);
        await tastingLogService.markAsTasted(festival.id, 'd3');

        final drinks = await repository.getDrinks(festival);

        final byId = {for (final d in drinks) d.id: d};
        expect(byId['d1']!.isFavorite, isTrue);
        expect(byId['d1']!.rating, isNull);
        expect(byId['d1']!.isTasted, isFalse);
        expect(byId['d2']!.rating, 4);
        expect(byId['d2']!.isFavorite, isFalse);
        expect(byId['d3']!.isTasted, isTrue);
      });

      test('leaves all state unset when nothing is stored', () async {
        when(apiService.fetchDrinksByType(festival))
            .thenAnswer((_) async => ok([makeDrink('d1')]));

        final drinks = await repository.getDrinks(festival);

        expect(drinks.single.isFavorite, isFalse);
        expect(drinks.single.rating, isNull);
        expect(drinks.single.isTasted, isFalse);
      });

      test('returns an empty list when the API returns no drinks', () async {
        when(apiService.fetchDrinksByType(festival))
            .thenAnswer((_) async => ok(<Drink>[]));

        expect(await repository.getDrinks(festival), isEmpty);
      });

      test('throws when every beverage type fails', () async {
        when(apiService.fetchDrinksByType(festival)).thenAnswer(
          (_) async => const FestivalDrinksResult(
            drinksByType: {},
            failedTypes: {'beer': 'network error'},
          ),
        );

        expect(
          () => repository.getDrinks(festival),
          throwsA(isA<BeerApiException>()),
        );
      });

      test('writes fetched drinks to the cache', () async {
        when(apiService.fetchDrinksByType(festival))
            .thenAnswer((_) async => ok([makeDrink('d1'), makeDrink('d2')]));

        await repository.getDrinks(festival);
        await pumpEventQueue(); // cache write is intentionally backgrounded

        final cached = cacheService.read(festival.id);
        expect(cached, isNotNull);
        expect(cached!.map((d) => d.id), containsAll(['d1', 'd2']));
      });

      test('keeps cached data for a beverage type that fails to refresh',
          () async {
        // First load: both beer and cider succeed and are cached.
        when(apiService.fetchDrinksByType(festival)).thenAnswer(
          (_) async => FestivalDrinksResult(
            drinksByType: {
              'beer': [makeDrink('beer-1')],
              'cider': [makeDrink('cider-1')],
            },
            failedTypes: const {},
          ),
        );
        await repository.getDrinks(festival);
        await pumpEventQueue();

        // Second load: cider fails (network), only beer refreshes.
        when(apiService.fetchDrinksByType(festival)).thenAnswer(
          (_) async => FestivalDrinksResult(
            drinksByType: {
              'beer': [makeDrink('beer-2')],
            },
            failedTypes: const {'cider': 'network error'},
          ),
        );
        final drinks = await repository.getDrinks(festival);

        final ids = drinks.map((d) => d.id).toSet();
        // Stale cider retained; beer refreshed; old beer dropped.
        expect(ids, containsAll(['beer-2', 'cider-1']));
        expect(ids.contains('beer-1'), isFalse);
      });
    });

    group('getCachedDrinks', () {
      test('returns null when nothing is cached', () async {
        expect(await repository.getCachedDrinks(festival), isNull);
      });

      test('returns cached drinks with user state applied', () async {
        when(apiService.fetchDrinksByType(festival))
            .thenAnswer((_) async => ok([makeDrink('d1'), makeDrink('d2')]));
        // Populate the cache via a live fetch.
        await repository.getDrinks(festival);
        await pumpEventQueue();

        // Set user state after caching; getCachedDrinks must re-apply it.
        await favoritesService.addFavorite(festival.id, 'd1');
        await ratingsService.setRating(festival.id, 'd2', 5);

        final cached = await repository.getCachedDrinks(festival);

        expect(cached, isNotNull);
        final byId = {for (final d in cached!) d.id: d};
        expect(byId['d1']!.isFavorite, isTrue);
        expect(byId['d2']!.rating, 5);
      });
    });

    group('favourite delegation', () {
      test('getFavorites returns stored favourites', () async {
        await favoritesService.addFavorite(festival.id, 'd1');

        expect(await repository.getFavorites(festival.id), equals(['d1']));
      });

      test('toggleFavorite adds then removes a favourite', () async {
        expect(await repository.toggleFavorite(festival.id, 'd1'), isTrue);
        expect(favoritesService.isFavorite(festival.id, 'd1'), isTrue);

        expect(await repository.toggleFavorite(festival.id, 'd1'), isFalse);
        expect(favoritesService.isFavorite(festival.id, 'd1'), isFalse);
      });
    });

    group('rating delegation', () {
      test('setRating then getRating round-trips the value', () async {
        await repository.setRating(festival.id, 'd1', 5);

        expect(await repository.getRating(festival.id, 'd1'), 5);
      });

      test('removeRating clears a stored rating', () async {
        await repository.setRating(festival.id, 'd1', 3);
        await repository.removeRating(festival.id, 'd1');

        expect(await repository.getRating(festival.id, 'd1'), isNull);
      });
    });

    group('tasted delegation', () {
      test('hasTasted reflects the tasting log', () async {
        expect(await repository.hasTasted(festival.id, 'd1'), isFalse);

        await tastingLogService.markAsTasted(festival.id, 'd1');

        expect(await repository.hasTasted(festival.id, 'd1'), isTrue);
      });

      test('toggleTasted returns the resulting tasted state', () async {
        expect(await repository.toggleTasted(festival.id, 'd1'), isTrue);
        expect(await repository.toggleTasted(festival.id, 'd1'), isFalse);
      });

      test('getTastedDrinks lists tasted drink IDs', () async {
        await tastingLogService.markAsTasted(festival.id, 'd1');
        await tastingLogService.markAsTasted(festival.id, 'd2');

        expect(
          await repository.getTastedDrinks(festival.id),
          containsAll(['d1', 'd2']),
        );
      });
    });
  });
}
