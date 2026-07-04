import 'dart:async';

import 'package:cambridge_beer_festival/domain/repositories/repositories.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_drink_repository_test.mocks.dart';

@GenerateNiceMocks([MockSpec<BeerApiService>(), MockSpec<AnalyticsService>()])
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

  Drink makeDrinkWithStatus(String id, String statusText) => Drink(
    product: Product(
      id: id,
      name: 'Drink $id',
      category: 'beer',
      dispense: 'cask',
      abv: 4.0,
      statusText: statusText,
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
    late SharedPreferencesUserDataStore userDataStore;
    late DrinkCacheService cacheService;
    late MockAnalyticsService analyticsService;
    late ApiDrinkRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      apiService = MockBeerApiService();
      userDataStore = SharedPreferencesUserDataStore(prefs);
      cacheService = DrinkCacheService(prefs);
      analyticsService = MockAnalyticsService();
      repository = ApiDrinkRepository(
        apiService: apiService,
        userDataStore: userDataStore,
        cacheService: cacheService,
        analyticsService: analyticsService,
      );
    });

    FestivalDrinksResult ok(List<Drink> drinks, {String type = 'beer'}) =>
        FestivalDrinksResult(
          drinksByType: {type: drinks},
          failedTypes: const {},
        );

    group('getDrinks', () {
      test(
        'populates favourite, rating and tasted state in one pass',
        () async {
          when(apiService.fetchDrinksByType(festival)).thenAnswer(
            (_) async =>
                ok([makeDrink('d1'), makeDrink('d2'), makeDrink('d3')]),
          );
          await repository.toggleFavorite(festival.id, 'd1');
          await repository.setRating(festival.id, 'd2', 4);
          await repository.toggleTasted(festival.id, 'd3');

          final drinks = await repository.getDrinks(festival);

          final byId = {for (final d in drinks) d.id: d};
          expect(byId['d1']!.isFavorite, isTrue);
          expect(byId['d1']!.rating, isNull);
          expect(byId['d1']!.isTasted, isFalse);
          expect(byId['d2']!.rating, 4);
          expect(byId['d2']!.isFavorite, isFalse);
          expect(byId['d3']!.isTasted, isTrue);
        },
      );

      test('leaves all state unset when nothing is stored', () async {
        when(
          apiService.fetchDrinksByType(festival),
        ).thenAnswer((_) async => ok([makeDrink('d1')]));

        final drinks = await repository.getDrinks(festival);

        expect(drinks.single.isFavorite, isFalse);
        expect(drinks.single.rating, isNull);
        expect(drinks.single.isTasted, isFalse);
      });

      test('returns an empty list when the API returns no drinks', () async {
        when(
          apiService.fetchDrinksByType(festival),
        ).thenAnswer((_) async => ok(<Drink>[]));

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
        when(
          apiService.fetchDrinksByType(festival),
        ).thenAnswer((_) async => ok([makeDrink('d1'), makeDrink('d2')]));

        await repository.getDrinks(festival);
        await pumpEventQueue(); // cache write is intentionally backgrounded

        final cached = cacheService.read(festival.id);
        expect(cached, isNotNull);
        expect(cached!.map((d) => d.id), containsAll(['d1', 'd2']));
      });

      test(
        'keeps cached data for a beverage type that fails to refresh',
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
        },
      );

      test(
        'keeps cached data for a beverage type that 404s on refresh',
        () async {
          // First load: both beer and cider 200 and are cached.
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

          // Second load: cider responds 404 → omitted from BOTH drinksByType
          // AND failedTypes (per fetchDrinksByType's contract), so the cache
          // must preserve cider rather than overwriting it with empty.
          when(apiService.fetchDrinksByType(festival)).thenAnswer(
            (_) async => FestivalDrinksResult(
              drinksByType: {
                'beer': [makeDrink('beer-2')],
              },
              failedTypes: const {},
            ),
          );
          final drinks = await repository.getDrinks(festival);

          final ids = drinks.map((d) => d.id).toSet();
          expect(ids, containsAll(['beer-2', 'cider-1']));
          expect(ids.contains('beer-1'), isFalse);
        },
      );

      test('logs unknown availability status texts to analytics', () async {
        when(apiService.fetchDrinksByType(festival)).thenAnswer(
          (_) async => ok([makeDrinkWithStatus('d1', 'Not yet available')]),
        );

        await repository.getDrinks(festival);

        verify(
          analyticsService.logError(
            any,
            any,
            reason: argThat(
              allOf(contains('Not yet available'), contains(festival.id)),
              named: 'reason',
            ),
          ),
        ).called(1);
      });

      test(
        'does not log analytics when all status texts are known vocabulary',
        () async {
          when(apiService.fetchDrinksByType(festival)).thenAnswer(
            (_) async => ok([
              makeDrinkWithStatus('d1', 'Sold Out'),
              makeDrinkWithStatus('d2', 'Plenty Left'),
              makeDrink('d3'),
            ]),
          );

          await repository.getDrinks(festival);

          verifyNever(
            analyticsService.logError(
              any,
              any,
              reason: argThat(contains('sample='), named: 'reason'),
            ),
          );
        },
      );

      test(
        'logs cache write failures to analytics instead of swallowing them',
        () async {
          // SharedPreferences mock can't fail directly, but we can drive the
          // analytics path by handing back an already-failed `written` future
          // via a fake cache that always fails on persist.
          final prefs = await SharedPreferences.getInstance();
          final failingCache = _FailingDrinkCacheService(prefs);
          final repo = ApiDrinkRepository(
            apiService: apiService,
            userDataStore: userDataStore,
            cacheService: failingCache,
            analyticsService: analyticsService,
          );

          when(
            apiService.fetchDrinksByType(festival),
          ).thenAnswer((_) async => ok([makeDrink('d1')]));

          await repo.getDrinks(festival);
          await pumpEventQueue();

          verify(
            analyticsService.logError(
              any,
              any,
              reason: argThat(contains('cache write failed'), named: 'reason'),
            ),
          ).called(1);
        },
      );

      test(
        'logs partial failure to analytics when a non-connectivity type fails',
        () async {
          when(apiService.fetchDrinksByType(festival)).thenAnswer(
            (_) async => FestivalDrinksResult(
              drinksByType: {
                'beer': [makeDrink('beer-1')],
              },
              failedTypes: {'cider': BeerApiException('HTTP 500')},
            ),
          );

          await repository.getDrinks(festival);
          await pumpEventQueue();

          verify(
            analyticsService.logError(
              any,
              any,
              reason: argThat(
                allOf(contains('cider'), contains(festival.id)),
                named: 'reason',
              ),
            ),
          ).called(1);
        },
      );

      test(
        'does not log partial failure to analytics when all failures are connectivity errors',
        () async {
          when(apiService.fetchDrinksByType(festival)).thenAnswer(
            (_) async => FestivalDrinksResult(
              drinksByType: {
                'beer': [makeDrink('beer-1')],
              },
              failedTypes: {'cider': TimeoutException('timeout')},
            ),
          );

          await repository.getDrinks(festival);
          await pumpEventQueue();

          verifyNever(
            analyticsService.logError(
              any,
              any,
              reason: argThat(contains('failed='), named: 'reason'),
            ),
          );
        },
      );

      test(
        'logs only non-connectivity failures when mixed with connectivity errors',
        () async {
          when(apiService.fetchDrinksByType(festival)).thenAnswer(
            (_) async => FestivalDrinksResult(
              drinksByType: {
                'beer': [makeDrink('beer-1')],
              },
              failedTypes: {
                'cider': TimeoutException('timeout'), // connectivity
                'perry': BeerApiException('HTTP 500'), // non-connectivity
              },
            ),
          );

          await repository.getDrinks(festival);
          await pumpEventQueue();

          verify(
            analyticsService.logError(
              any,
              any,
              reason: argThat(
                allOf(
                  contains('perry'),
                  contains(festival.id),
                  isNot(contains('cider')), // connectivity failure excluded
                ),
                named: 'reason',
              ),
            ),
          ).called(1);
        },
      );
    });

    group('getCachedDrinks', () {
      test('returns null when nothing is cached', () async {
        expect(await repository.getCachedDrinks(festival), isNull);
      });

      test('returns cached drinks with user state applied', () async {
        when(
          apiService.fetchDrinksByType(festival),
        ).thenAnswer((_) async => ok([makeDrink('d1'), makeDrink('d2')]));
        // Populate the cache via a live fetch.
        await repository.getDrinks(festival);
        await pumpEventQueue();

        // Set user state after caching; getCachedDrinks must re-apply it.
        await repository.toggleFavorite(festival.id, 'd1');
        await repository.setRating(festival.id, 'd2', 5);

        final cached = await repository.getCachedDrinks(festival);

        expect(cached, isNotNull);
        final byId = {for (final d in cached!) d.id: d};
        expect(byId['d1']!.isFavorite, isTrue);
        expect(byId['d2']!.rating, 5);
      });
    });

    group('favourite delegation', () {
      test('getFavorites returns stored favourites', () async {
        await repository.toggleFavorite(festival.id, 'd1');

        expect(await repository.getFavorites(festival.id), equals(['d1']));
      });

      test('toggleFavorite adds then removes a favourite', () async {
        expect(
          (await repository.toggleFavorite(festival.id, 'd1'))?.wantToTry,
          isTrue,
        );
        expect(userDataStore.read(festival.id, 'd1')?.wantToTry, isTrue);

        expect(await repository.toggleFavorite(festival.id, 'd1'), isNull);
        expect(
          userDataStore.read(festival.id, 'd1')?.wantToTry ?? false,
          isFalse,
        );
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

    group('dispose', () {
      test('closes the api service', () {
        repository.dispose();
        verify(apiService.dispose()).called(1);
      });
    });

    group('tasted delegation', () {
      test('hasTasted reflects the tasting log', () async {
        expect(await repository.hasTasted(festival.id, 'd1'), isFalse);

        await repository.toggleTasted(festival.id, 'd1');

        expect(await repository.hasTasted(festival.id, 'd1'), isTrue);
      });

      test('toggleTasted returns the resulting tasted state', () async {
        expect(
          (await repository.toggleTasted(festival.id, 'd1'))?.isTasted,
          isTrue,
        );
        expect(await repository.toggleTasted(festival.id, 'd1'), isNull);
      });

      test('getTastedDrinks lists tasted drink IDs', () async {
        await repository.toggleTasted(festival.id, 'd1');
        await repository.toggleTasted(festival.id, 'd2');

        expect(
          await repository.getTastedDrinks(festival.id),
          containsAll(['d1', 'd2']),
        );
      });
    });

    group('addTasting', () {
      test('appends a tasting event to an empty record', () async {
        final now = DateTime(2026, 6, 10, 14, 30);

        final result = await repository.addTasting(festival.id, 'd1', now: now);

        expect(result?.tastingEvents, equals([now]));
        expect(result?.wantToTry, isFalse);
      });

      test('appends without clearing existing events', () async {
        final time1 = DateTime(2026, 6, 10, 10, 0);
        final time2 = DateTime(2026, 6, 10, 14, 30);

        await repository.addTasting(festival.id, 'd1', now: time1);
        final result = await repository.addTasting(
          festival.id,
          'd1',
          now: time2,
        );

        expect(result?.tastingEvents, equals([time1, time2]));
      });

      test('preserves wantToTry', () async {
        final now = DateTime(2026, 6, 10, 14, 30);
        await repository.toggleFavorite(festival.id, 'd1');

        final result = await repository.addTasting(festival.id, 'd1', now: now);

        expect(result?.wantToTry, isTrue);
        expect(result?.tastingEvents.length, equals(1));
      });

      test('uses the provided now for updatedAt', () async {
        final now = DateTime(2026, 6, 10, 14, 30);

        final result = await repository.addTasting(festival.id, 'd1', now: now);

        expect(result?.updatedAt, equals(now));
      });

      test('allows duplicate identical timestamps', () async {
        final now = DateTime(2026, 6, 10, 14, 30);

        await repository.addTasting(festival.id, 'd1', now: now);
        final result = await repository.addTasting(festival.id, 'd1', now: now);

        expect(result?.tastingCount, equals(2));
      });

      test('defaults to the current time when now is omitted', () async {
        // Margin absorbs the constructor's millisecond truncation, which can
        // round the event a fraction below a now() captured just beforehand.
        final before = DateTime.now().subtract(const Duration(seconds: 1));

        final result = await repository.addTasting(festival.id, 'd1');

        expect(result?.tastingCount, equals(1));
        expect(result!.tastingEvents.single.isAfter(before), isTrue);
      });
    });

    group('removeTasting', () {
      test('returns null when no record exists', () async {
        final event = DateTime(2026, 6, 10, 14, 30);

        final result = await repository.removeTasting(festival.id, 'd1', event);

        expect(result, isNull);
      });

      test('removes exactly one occurrence when duplicates exist', () async {
        final now = DateTime(2026, 6, 10, 14, 30);
        await repository.addTasting(festival.id, 'd1', now: now);
        await repository.addTasting(festival.id, 'd1', now: now);

        final result = await repository.removeTasting(festival.id, 'd1', now);

        expect(result?.tastingCount, equals(1));
      });

      test(
        'returns the state unchanged when the event is not present',
        () async {
          final time1 = DateTime(2026, 6, 10, 10, 0);
          final time2 = DateTime(2026, 6, 10, 14, 30);
          await repository.addTasting(festival.id, 'd1', now: time1);

          final result = await repository.removeTasting(
            festival.id,
            'd1',
            time2,
          );

          expect(result?.tastingCount, equals(1));
          expect(result?.tastingEvents.contains(time1), isTrue);
        },
      );

      test('prunes to null when removing the last event', () async {
        final now = DateTime(2026, 6, 10, 14, 30);
        await repository.addTasting(festival.id, 'd1', now: now);

        final result = await repository.removeTasting(festival.id, 'd1', now);

        expect(result, isNull);
        expect(userDataStore.read(festival.id, 'd1'), isNull);
      });

      test('reverts to want-to-try', () async {
        final now = DateTime(2026, 6, 10, 14, 30);
        await repository.toggleFavorite(festival.id, 'd1');
        await repository.addTasting(festival.id, 'd1', now: now);

        final result = await repository.removeTasting(festival.id, 'd1', now);

        expect(result, isNotNull);
        expect(result?.wantToTry, isTrue);
        expect(result?.tastingEvents, isEmpty);
      });

      test('deletes an event recorded with sub-millisecond precision', () async {
        // Simulates the real path: DateTime.now() carries microseconds, but the
        // store persists millis. The event handed back to the caller from
        // addTasting must still match the persisted form on delete.
        final subMillis = DateTime.fromMicrosecondsSinceEpoch(
          DateTime(2026, 6, 10, 14, 30).microsecondsSinceEpoch + 456,
        );
        final added = await repository.addTasting(
          festival.id,
          'd1',
          now: subMillis,
        );
        final event = added!.tastingEvents.single;

        final result = await repository.removeTasting(festival.id, 'd1', event);

        expect(result, isNull);
        expect(userDataStore.read(festival.id, 'd1'), isNull);
      });
    });

    group('setUserNotes', () {
      test('sets notes on a fresh record', () async {
        final result = await repository.setUserNotes(
          festival.id,
          'd1',
          'Lovely hoppy finish',
        );

        expect(result?.notes, equals('Lovely hoppy finish'));
      });

      test('overwrites existing notes', () async {
        await repository.setUserNotes(festival.id, 'd1', 'First notes');

        final result = await repository.setUserNotes(
          festival.id,
          'd1',
          'Updated notes',
        );

        expect(result?.notes, equals('Updated notes'));
      });

      test(
        'clearing a note leaves the tasting it was attached to (ADR 0006)',
        () async {
          // Noting a never-tasted drink synthesises a tasting to carry the note.
          await repository.setUserNotes(festival.id, 'd1', 'Some notes');

          // Clearing the note does not delete the tasting — a tasting is a real
          // event, removed only by an explicit delete.
          final result = await repository.setUserNotes(festival.id, 'd1', null);

          expect(result, isNotNull);
          expect(result?.notes, isNull);
          expect(result?.isTasted, isTrue);
        },
      );

      test('clearing notes preserves other signals', () async {
        await repository.setRating(festival.id, 'd1', 4);
        await repository.setUserNotes(festival.id, 'd1', 'Some notes');

        final result = await repository.setUserNotes(festival.id, 'd1', null);

        expect(result, isNotNull);
        expect(result?.rating, equals(4));
        expect(result?.notes, isNull);
      });

      test(
        'normalises an empty string to null (not a distinct signal)',
        () async {
          await repository.setRating(festival.id, 'd1', 4);

          final result = await repository.setUserNotes(festival.id, 'd1', '');

          expect(result, isNotNull);
          expect(result?.rating, equals(4));
          expect(result?.notes, isNull);
        },
      );
    });
  });
}

/// Drink cache subclass whose merge() always returns a failed `written` future,
/// so we can verify the repository surfaces persistence errors via analytics
/// rather than letting them become unhandled async errors.
class _FailingDrinkCacheService extends DrinkCacheService {
  _FailingDrinkCacheService(super.prefs);

  @override
  DrinkCacheUpdate merge(
    String festivalId,
    Map<String, List<Drink>> freshByType,
  ) {
    final drinks = [for (final list in freshByType.values) ...list];
    return DrinkCacheUpdate(
      drinks,
      Future<void>.error(StateError('persist failed')),
    );
  }
}
