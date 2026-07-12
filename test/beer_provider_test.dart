import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/domain/models/models.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

// Integration tests for BeerProvider
//
// These tests verify that BeerProvider correctly orchestrates domain services
// (DrinkFilterService, DrinkSortService) and manages state.
//
// For isolated unit tests of filtering and sorting logic, see:
// - test/domain/services/drink_filter_service_test.dart
// - test/domain/services/drink_sort_service_test.dart

// Test helper to create sample drinks
List<Drink> createSampleDrinks() {
  final producer1 = Producer.fromJson({
    'id': 'brewery-1',
    'name': 'Test Brewery',
    'location': 'Cambridge',
    'products': [],
  });

  final producer2 = Producer.fromJson({
    'id': 'brewery-2',
    'name': 'Another Brewery',
    'location': 'London',
    'products': [],
  });

  final product1 = Product.fromJson({
    'id': 'drink-1',
    'name': 'Alpha Ale',
    'category': 'beer',
    'style': 'IPA',
    'dispense': 'cask',
    'abv': '5.5',
    'notes': 'A hoppy IPA',
  });

  final product2 = Product.fromJson({
    'id': 'drink-2',
    'name': 'Beta Bitter',
    'category': 'beer',
    'style': 'Bitter',
    'dispense': 'cask',
    'abv': '4.2',
  });

  final product3 = Product.fromJson({
    'id': 'drink-3',
    'name': 'Crisp Cider',
    'category': 'cider',
    'style': 'Dry',
    'dispense': 'bag in box',
    'abv': '6.0',
  });

  final product4 = Product.fromJson({
    'id': 'drink-4',
    'name': 'Zesty Zider',
    'category': 'cider',
    'style': 'Sweet',
    'dispense': 'keg',
    'abv': '4.5',
    'notes': 'sweet and fruity',
  });

  return [
    Drink(product: product1, producer: producer1, festivalId: 'cbf2025'),
    Drink(product: product2, producer: producer1, festivalId: 'cbf2025'),
    Drink(product: product3, producer: producer2, festivalId: 'cbf2025'),
    Drink(product: product4, producer: producer2, festivalId: 'cbf2025'),
  ];
}

/// Test-data factory for a [Festival] with sensible defaults.
Festival createSampleFestival({
  String id = 'cbf2025',
  String name = 'Cambridge Beer Festival 2025',
  List<String> availableBeverageTypes = const ['beer'],
}) => Festival(
  id: id,
  name: name,
  dataBaseUrl: 'https://data.cambeerfestival.app/$id',
  availableBeverageTypes: availableBeverageTypes,
);

void main() {
  group('BeerProvider', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    setUp(() {
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();
      SharedPreferences.setMockInitialValues({});

      // Default mock setup - only essentials for initialize()
      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [DefaultFestivals.cambridge2025],
          defaultFestivalId: DefaultFestivals.cambridge2025.id,
          version: '1.0',
          baseUrl: 'https://data.cambeerfestival.app',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);
    });

    tearDown(() {
      provider.dispose();
    });

    group('initialization', () {
      test('starts with empty drinks list', () {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        expect(provider.drinks, isEmpty);
        expect(provider.allDrinks, isEmpty);
      });

      test('starts with default festival when not initialized', () {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        expect(
          provider.currentFestival.id,
          DefaultFestivals.all.firstWhere((f) => f.isActive).id,
        );
      });

      test('isLoading is false initially', () {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        expect(provider.isLoading, isFalse);
      });

      test('error is null initially', () {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        expect(provider.error, isNull);
      });
    });

    group('loadDrinks', () {
      test('loads drinks successfully', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);

        await provider.loadDrinks();

        expect(provider.allDrinks.length, 4);
        expect(provider.drinks.length, 4);
        expect(provider.error, isNull);
      });

      test('clears error on successful load', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        // First, cause an error
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenThrow(BeerApiException('Error', 500));
        await provider.loadDrinks();
        expect(provider.error, isNotNull);

        // Then load successfully
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => <Drink>[]);
        await provider.loadDrinks();
        expect(provider.error, isNull);
      });
    });

    group('category filter', () {
      test('setCategory filters drinks by category', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setCategory('beer');

        expect(provider.drinks.length, 2);
        expect(provider.drinks.every((d) => d.category == 'beer'), isTrue);
      });

      test('setCategory with null shows all drinks', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setCategory('beer');
        expect(provider.drinks.length, 2);

        provider.setCategory(null);
        expect(provider.drinks.length, 4);
      });

      test('setCategory clears style filter', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.toggleStyle('IPA');
        expect(provider.selectedStyles, contains('IPA'));

        provider.setCategory('cider');
        expect(provider.selectedStyles, isEmpty);
      });

      test('availableCategories returns unique categories', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        final categories = provider.availableCategories;
        expect(categories.length, 2);
        expect(categories, containsAll(['beer', 'cider']));
      });

      test('categoryCountsMap returns correct counts', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        final counts = provider.categoryCountsMap;
        expect(counts['beer'], 2);
        expect(counts['cider'], 2);
      });
    });

    group('style filter', () {
      test('toggleStyle adds style to filter', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.toggleStyle('IPA');

        expect(provider.selectedStyles, contains('IPA'));
        expect(provider.drinks.length, 1);
        expect(provider.drinks.first.style, 'IPA');
      });

      test('toggleStyle removes style when already selected', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider
          ..toggleStyle('IPA')
          ..toggleStyle('IPA');

        expect(provider.selectedStyles, isEmpty);
        expect(provider.drinks.length, 4);
      });

      test('multiple styles selected uses OR logic', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider
          ..toggleStyle('IPA')
          ..toggleStyle('Bitter');

        expect(provider.selectedStyles.length, 2);
        expect(provider.drinks.length, 2);
      });

      test('clearStyles removes all style filters', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider
          ..toggleStyle('IPA')
          ..toggleStyle('Bitter')
          ..clearStyles();

        expect(provider.selectedStyles, isEmpty);
        expect(provider.drinks.length, 4);
      });

      test('availableStyles respects category filter', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setCategory('beer');
        final beerStyles = provider.availableStyles;
        expect(beerStyles, containsAll(['IPA', 'Bitter']));
        expect(beerStyles, isNot(contains('Dry')));
        expect(beerStyles, isNot(contains('Sweet')));
      });
    });

    group('sorting', () {
      test('setSort with nameAsc sorts alphabetically', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSort(DrinkSort.nameAsc);

        expect(provider.drinks.first.name, 'Alpha Ale');
        expect(provider.drinks.last.name, 'Zesty Zider');
      });

      test('setSort with nameDesc sorts reverse alphabetically', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSort(DrinkSort.nameDesc);

        expect(provider.drinks.first.name, 'Zesty Zider');
        expect(provider.drinks.last.name, 'Alpha Ale');
      });

      test('setSort with abvHigh sorts by ABV descending', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSort(DrinkSort.abvHigh);

        expect(provider.drinks.first.abv, 6.0);
        expect(provider.drinks.last.abv, 4.2);
      });

      test('setSort with abvLow sorts by ABV ascending', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSort(DrinkSort.abvLow);

        expect(provider.drinks.first.abv, 4.2);
        expect(provider.drinks.last.abv, 6.0);
      });

      test('setSort with brewery sorts by brewery name', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSort(DrinkSort.brewery);

        expect(provider.drinks.first.breweryName, 'Another Brewery');
        expect(provider.drinks.last.breweryName, 'Test Brewery');
      });

      test('setSort with style sorts by style name', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSort(DrinkSort.style);

        // Bitter, Dry, IPA, Sweet
        expect(provider.drinks.first.style, 'Bitter');
        expect(provider.drinks.last.style, 'Sweet');
      });
    });

    group('search', () {
      test('setSearchQuery filters by drink name', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSearchQuery('alpha');

        expect(provider.drinks.length, 1);
        expect(provider.drinks.first.name, 'Alpha Ale');
      });

      test('setSearchQuery filters by brewery name', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSearchQuery('another');

        expect(provider.drinks.length, 2);
        expect(
          provider.drinks.every((d) => d.breweryName == 'Another Brewery'),
          isTrue,
        );
      });

      test('setSearchQuery filters by style', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSearchQuery('ipa');

        expect(provider.drinks.length, 1);
        expect(provider.drinks.first.style, 'IPA');
      });

      test('setSearchQuery filters by notes', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSearchQuery('fruity');

        expect(provider.drinks.length, 1);
        expect(provider.drinks.first.name, 'Zesty Zider');
      });

      test('setSearchQuery is case insensitive', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSearchQuery('ALPHA');

        expect(provider.drinks.length, 1);
        expect(provider.drinks.first.name, 'Alpha Ale');
      });

      test('setSearchQuery with empty string shows all drinks', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSearchQuery('alpha');
        expect(provider.drinks.length, 1);

        provider.setSearchQuery('');
        expect(provider.drinks.length, 4);
      });
    });

    group('favorites filter', () {
      test('setShowFavoritesOnly filters to favorites', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        // Mock toggleFavorite to properly toggle state
        final favorites = <String>{};
        when(mockDrinkRepository.toggleFavorite(any, any)).thenAnswer((
          invocation,
        ) async {
          final drinkId = invocation.positionalArguments[1] as String;
          if (favorites.contains(drinkId)) {
            favorites.remove(drinkId);
            return null;
          } else {
            favorites.add(drinkId);
            return UserDrinkState(
              wantToTry: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
        });

        // Toggle favorites after loading (simulates user action)
        await provider.toggleFavorite(provider.allDrinks[0]);
        await provider.toggleFavorite(provider.allDrinks[2]);

        provider.setShowFavoritesOnly(value: true);

        expect(provider.drinks.length, 2);
        expect(provider.drinks.every((d) => d.isFavorite), isTrue);
      });

      test(
        'favoriteEntries returns hydrated entries when catalogue is loaded',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          final sampleDrinks = createSampleDrinks();

          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => sampleDrinks);
          await provider.loadDrinks();

          // Stub getPersonalEntries to return a wantToTry record for drink-1
          final now = DateTime.now();
          final state = UserDrinkState(
            wantToTry: true,
            createdAt: now,
            updatedAt: now,
          );
          when(
            mockDrinkRepository.getPersonalEntries(any),
          ).thenReturn({'drink-1': state});

          final entries = provider.favoriteEntries;

          expect(entries.length, 1);
          // Catalogue is loaded — drink must be hydrated
          expect(entries.first.isCatalogueLoaded, isTrue);
          expect(entries.first.drink, isNotNull);
          expect(entries.first.drink!.name, 'Alpha Ale');
          expect(entries.first.drinkId, 'drink-1');
        },
      );

      test(
        'favoriteEntries returns placeholder entries when catalogue not loaded'
        ' but store has favourite',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          // Catalogue is NOT loaded — getDrinks returns empty list
          when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);
          await provider.loadDrinks();

          // Store has a wantToTry record for drink-1
          final now = DateTime.now();
          final state = UserDrinkState(
            wantToTry: true,
            createdAt: now,
            updatedAt: now,
          );
          when(
            mockDrinkRepository.getPersonalEntries(any),
          ).thenReturn({'drink-1': state});

          final entries = provider.favoriteEntries;

          // Entry is present even without the catalogue — this is the #390/#310
          // fix: personal-state query is catalogue-independent.
          expect(entries.length, 1);
          expect(entries.first.drinkId, 'drink-1');
          // Catalogue not loaded — drink is null
          expect(entries.first.isCatalogueLoaded, isFalse);
          expect(entries.first.drink, isNull);
        },
      );

      test('favoriteEntries are returned in a stable, sorted order', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();
        when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);
        await provider.loadDrinks();

        final now = DateTime.now();
        UserDrinkState fav() =>
            UserDrinkState(wantToTry: true, createdAt: now, updatedAt: now);
        // Insertion order is deliberately unsorted; the store iterates an
        // unordered key set, so favoriteEntries must impose a stable order.
        when(
          mockDrinkRepository.getPersonalEntries(any),
        ).thenReturn({'zulu': fav(), 'alpha': fav(), 'mike': fav()});

        final ids = provider.favoriteEntries.map((e) => e.drinkId).toList();
        expect(ids, ['alpha', 'mike', 'zulu']);
      });

      test(
        'favoriteEntries memoises and recomputes only when invalidated',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();
          when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);
          await provider.loadDrinks();

          final now = DateTime.now();
          when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
            'drink-1': UserDrinkState(
              wantToTry: true,
              createdAt: now,
              updatedAt: now,
            ),
          });

          // First read computes; second read must reuse the cached instance.
          final firstRead = provider.favoriteEntries;
          final secondRead = provider.favoriteEntries;
          expect(identical(firstRead, secondRead), isTrue);

          // Reloading the catalogue reassigns _allDrinks → cache invalidated.
          await provider.loadDrinks();
          final afterReload = provider.favoriteEntries;
          expect(identical(secondRead, afterReload), isFalse);

          // Three reads, but only two computes: the cached middle read did not
          // re-query the store, and the post-reload read recomputed. A total of
          // 1 would mean the cache never invalidated; 3 would mean no caching.
          verify(mockDrinkRepository.getPersonalEntries(any)).called(2);
        },
      );
    });

    group('myFestivalEntries', () {
      setUp(() async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();
        when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);
        await provider.loadDrinks();
      });

      test('tasted-only entry appears in tasted list, not wantToTry', () async {
        final now = DateTime.now();
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-1': UserDrinkState(
            wantToTry: false,
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        });

        final result = provider.myFestivalEntries;
        expect(result.wantToTry, isEmpty);
        expect(result.tasted.length, 1);
        expect(result.tasted.first.drinkId, 'drink-1');
      });

      test('entry with both flags appears in both lists', () async {
        final now = DateTime.now();
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-1': UserDrinkState(
            wantToTry: true,
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        });

        final result = provider.myFestivalEntries;
        expect(result.wantToTry.length, 1);
        expect(result.tasted.length, 1);
        expect(result.wantToTry.first.drinkId, 'drink-1');
        expect(result.tasted.first.drinkId, 'drink-1');
      });

      test('entry with neither flag excluded from both lists', () async {
        final now = DateTime.now();
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-1': UserDrinkState(rating: 3, createdAt: now, updatedAt: now),
        });

        final result = provider.myFestivalEntries;
        expect(result.wantToTry, isEmpty);
        expect(result.tasted, isEmpty);
      });

      test('wantToTry list is sorted alphabetically', () async {
        final now = DateTime.now();
        UserDrinkState fav() =>
            UserDrinkState(wantToTry: true, createdAt: now, updatedAt: now);
        when(
          mockDrinkRepository.getPersonalEntries(any),
        ).thenReturn({'zulu': fav(), 'alpha': fav(), 'mike': fav()});

        final ids = provider.myFestivalEntries.wantToTry
            .map((e) => e.drinkId)
            .toList();
        expect(ids, ['alpha', 'mike', 'zulu']);
      });

      test('unloaded placeholder entries sort after named entries', () async {
        final now = DateTime.now();
        UserDrinkState fav() =>
            UserDrinkState(wantToTry: true, createdAt: now, updatedAt: now);
        // drink-1 is in createSampleDrinks() (name: 'Alpha Ale'); unknown-id
        // has no catalogue entry. Alpha Ale should appear first even though its
        // drinkId ('drink-1') sorts after 'unknown-id' lexically.
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());
        await provider.loadDrinks();
        when(
          mockDrinkRepository.getPersonalEntries(any),
        ).thenReturn({'unknown-id': fav(), 'drink-1': fav()});

        final ids = provider.myFestivalEntries.wantToTry
            .map((e) => e.drinkId)
            .toList();
        expect(ids, ['drink-1', 'unknown-id']);
      });

      test('tasted list is sorted by lastTastedAt descending', () async {
        final t1 = DateTime(2025, 1, 1);
        final t2 = DateTime(2025, 6, 1);
        final t3 = DateTime(2025, 3, 1);
        final now = DateTime.now();
        UserDrinkState tasted(DateTime tastedAt) => UserDrinkState(
          tastingEvents: [tastedAt],
          createdAt: now,
          updatedAt: now,
        );
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'alpha': tasted(t1),
          'bravo': tasted(t2),
          'charlie': tasted(t3),
        });

        // Expected: bravo (t2=June), charlie (t3=March), alpha (t1=Jan)
        final ids = provider.myFestivalEntries.tasted
            .map((e) => e.drinkId)
            .toList();
        expect(ids, ['bravo', 'charlie', 'alpha']);
      });

      test('memoises and recomputes only when invalidated', () async {
        final now = DateTime.now();
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-1': UserDrinkState(
            wantToTry: true,
            createdAt: now,
            updatedAt: now,
          ),
        });

        final first = provider.myFestivalEntries;
        final second = provider.myFestivalEntries;
        expect(identical(first, second), isTrue);

        await provider.loadDrinks();
        final afterReload = provider.myFestivalEntries;
        expect(identical(second, afterReload), isFalse);
      });
    });

    group('hide unavailable filter', () {
      test('setHideUnavailable filters out sold out drinks', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        // Create drinks with different availability statuses
        final producer = Producer.fromJson({
          'id': 'brewery-1',
          'name': 'Test Brewery',
          'location': 'Cambridge',
          'products': [],
        });

        final availableDrink = Drink(
          product: Product.fromJson({
            'id': 'drink-1',
            'name': 'Available Ale',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '5.0',
            'status_text': 'Plenty left',
          }),
          producer: producer,
          festivalId: 'cbf2025',
        );

        final soldOutDrink = Drink(
          product: Product.fromJson({
            'id': 'drink-2',
            'name': 'Sold Out Stout',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '6.0',
            'status_text': 'Sold out',
          }),
          producer: producer,
          festivalId: 'cbf2025',
        );

        final lowStockDrink = Drink(
          product: Product.fromJson({
            'id': 'drink-3',
            'name': 'Low Stock Lager',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '4.5',
            'status_text': 'Low stock remaining',
          }),
          producer: producer,
          festivalId: 'cbf2025',
        );

        final sampleDrinks = [availableDrink, soldOutDrink, lowStockDrink];

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        // Initially, all drinks should be visible
        expect(provider.drinks.length, 3);

        // Enable hide unavailable
        await provider.setHideUnavailable(value: true);

        // Sold out drink should be filtered out
        expect(provider.drinks.length, 2);
        expect(provider.drinks.any((d) => d.name == 'Sold Out Stout'), isFalse);
        expect(provider.drinks.any((d) => d.name == 'Available Ale'), isTrue);
        expect(provider.drinks.any((d) => d.name == 'Low Stock Lager'), isTrue);
      });

      test(
        'setHideUnavailable does not filter "not yet available" drinks',
        () async {
          // notYetAvailable was a dead enum value — no real festival data used it.
          // 'Not yet available' resolves to AvailabilityStatus.unknown (not in the
          // known vocabulary), so it is NOT filtered by setHideUnavailable.
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          final producer = Producer.fromJson({
            'id': 'brewery-1',
            'name': 'Test Brewery',
            'location': 'Cambridge',
            'products': [],
          });

          final availableDrink = Drink(
            product: Product.fromJson({
              'id': 'drink-1',
              'name': 'Available Ale',
              'category': 'beer',
              'dispense': 'cask',
              'abv': '5.0',
              'status_text': 'Arrived',
            }),
            producer: producer,
            festivalId: 'cbf2025',
          );

          final notYetDrink = Drink(
            product: Product.fromJson({
              'id': 'drink-2',
              'name': 'Coming Soon Cider',
              'category': 'cider',
              'dispense': 'keg',
              'abv': '5.5',
              'status_text': 'Not yet available',
            }),
            producer: producer,
            festivalId: 'cbf2025',
          );

          final sampleDrinks = [availableDrink, notYetDrink];

          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => sampleDrinks);
          await provider.loadDrinks();

          expect(provider.drinks.length, 2);

          await provider.setHideUnavailable(value: true);

          // 'Not yet available' resolves to unknown, so both drinks remain.
          expect(provider.drinks.length, 2);
          expect(
            provider.drinks.any((d) => d.name == 'Coming Soon Cider'),
            isTrue,
          );
          expect(provider.drinks.any((d) => d.name == 'Available Ale'), isTrue);
        },
      );

      test('setHideUnavailable persists preference', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        // Set hide unavailable via convenience wrapper
        await provider.setHideUnavailable(value: true);
        expect(provider.hideUnavailable, isTrue);
        expect(
          provider.visibilityFilters.contains(
            DrinkVisibilityFilter.availableOnly,
          ),
          isTrue,
        );

        // Verify it was persisted as the new visibilityFilters key, not the legacy key
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('visibilityFilters'),
          contains('availableOnly'),
        );
        expect(prefs.getBool('hideUnavailable'), isNull);

        // Disable it
        await provider.setHideUnavailable(value: false);
        expect(provider.hideUnavailable, isFalse);
        expect(
          prefs.getStringList('visibilityFilters'),
          isNot(contains('availableOnly')),
        );
      });

      test(
        'hideUnavailable preference is loaded on initialization (legacy migration)',
        () async {
          // Set legacy preference
          SharedPreferences.setMockInitialValues({'hideUnavailable': true});

          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          expect(provider.hideUnavailable, isTrue);
        },
      );

      test(
        'visibilityFilters preference is loaded on initialization',
        () async {
          // Set new-style preference
          SharedPreferences.setMockInitialValues({
            'visibilityFilters': ['availableOnly', 'notTasted'],
          });

          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          expect(
            provider.visibilityFilters,
            containsAll([
              DrinkVisibilityFilter.availableOnly,
              DrinkVisibilityFilter.notTasted,
            ]),
          );
        },
      );

      test(
        'setVisibilityFilter toggles individual filters independently',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          await provider.setVisibilityFilter(
            DrinkVisibilityFilter.veganOnly,
            active: true,
          );
          await provider.setVisibilityFilter(
            DrinkVisibilityFilter.notTasted,
            active: true,
          );

          expect(
            provider.visibilityFilters,
            contains(DrinkVisibilityFilter.veganOnly),
          );
          expect(
            provider.visibilityFilters,
            contains(DrinkVisibilityFilter.notTasted),
          );
          expect(provider.hideUnavailable, isFalse);

          // Turn off vegan only, notTasted should remain
          await provider.setVisibilityFilter(
            DrinkVisibilityFilter.veganOnly,
            active: false,
          );
          expect(
            provider.visibilityFilters,
            isNot(contains(DrinkVisibilityFilter.veganOnly)),
          );
          expect(
            provider.visibilityFilters,
            contains(DrinkVisibilityFilter.notTasted),
          );
        },
      );

      test('notTasted filter hides already-tasted drinks', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        sampleDrinks[0] = sampleDrinks[0].copyWith(
          userState: UserDrinkState.initial().copyWith(
            tastingEvents: [DateTime(2026, 5, 18)],
          ),
        );
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        expect(provider.drinks.length, sampleDrinks.length);

        await provider.setVisibilityFilter(
          DrinkVisibilityFilter.notTasted,
          active: true,
        );

        expect(provider.drinks.any((d) => d.isTasted), isFalse);
      });

      test(
        'toggleTasted refreshes filtered list while notTasted filter is active',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          final sampleDrinks = createSampleDrinks();
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => sampleDrinks);
          await provider.loadDrinks();

          await provider.setVisibilityFilter(
            DrinkVisibilityFilter.notTasted,
            active: true,
          );
          expect(provider.drinks.length, sampleDrinks.length);

          // Mark the first visible drink as tasted via the provider.
          final target = provider.drinks.first;
          when(
            mockDrinkRepository.toggleTasted(
              provider.currentFestival.id,
              target.id,
            ),
          ).thenAnswer(
            (_) async => UserDrinkState(
              tastingEvents: [DateTime.now()],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          await provider.toggleTasted(target);

          // With the not-tasted filter active the drink must drop out
          // of the visible list immediately.
          expect(provider.drinks.length, sampleDrinks.length - 1);
          expect(provider.drinks.any((d) => d.id == target.id), isFalse);
        },
      );

      test('veganOnly filter shows only vegan drinks', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final veganProduct = Product.fromJson({
          'id': 'vegan-1',
          'name': 'Vegan Ale',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4.0',
          'is_vegan': true,
        });
        final nonVeganProduct = Product.fromJson({
          'id': 'non-vegan-1',
          'name': 'Regular Ale',
          'category': 'beer',
          'dispense': 'cask',
          'abv': '4.0',
        });
        final producer = Producer.fromJson({
          'id': 'brewery-1',
          'name': 'Test Brewery',
          'location': 'Cambridge',
          'products': [],
        });
        final drinks = [
          Drink(product: veganProduct, producer: producer, festivalId: 'test'),
          Drink(
            product: nonVeganProduct,
            producer: producer,
            festivalId: 'test',
          ),
        ];

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => drinks);
        await provider.loadDrinks();

        expect(provider.drinks.length, 2);

        await provider.setVisibilityFilter(
          DrinkVisibilityFilter.veganOnly,
          active: true,
        );

        expect(provider.drinks.length, 1);
        expect(provider.drinks[0].isVegan, isTrue);
      });
    });

    group('allergen filters', () {
      late Producer producer;
      late Drink glutenDrink;
      late Drink sulphiteDrink;
      late Drink cleanDrink;

      setUp(() async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        producer = Producer.fromJson({
          'id': 'brewery-1',
          'name': 'Test Brewery',
          'location': 'Cambridge',
          'products': [],
        });
        glutenDrink = Drink(
          product: Product.fromJson({
            'id': 'g1',
            'name': 'Gluteny Ale',
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
            'id': 's1',
            'name': 'Sulphitey Ale',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '4.0',
            'allergens': {'sulphites': 1},
          }),
          producer: producer,
          festivalId: 'test',
        );
        cleanDrink = Drink(
          product: Product.fromJson({
            'id': 'c1',
            'name': 'Clean Ale',
            'category': 'beer',
            'dispense': 'cask',
            'abv': '4.0',
            'allergens': {},
          }),
          producer: producer,
          festivalId: 'test',
        );
      });

      test(
        'availableAllergens returns all allergen keys from loaded drinks',
        () async {
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => [glutenDrink, sulphiteDrink, cleanDrink]);
          await provider.loadDrinks();

          expect(
            provider.availableAllergens,
            containsAll(['gluten', 'sulphites']),
          );
        },
      );

      test(
        'setAllergenFilter gluten excludes drinks containing gluten',
        () async {
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => [glutenDrink, sulphiteDrink, cleanDrink]);
          await provider.loadDrinks();

          expect(provider.drinks.length, 3);
          await provider.setAllergenFilter('gluten', active: true);

          expect(provider.drinks.length, 2);
          expect(
            provider.drinks.any((d) => d.allergens['gluten'] == 1),
            isFalse,
          );
        },
      );

      test('multiple allergen filters are ANDed', () async {
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [glutenDrink, sulphiteDrink, cleanDrink]);
        await provider.loadDrinks();

        await provider.setAllergenFilter('gluten', active: true);
        await provider.setAllergenFilter('sulphites', active: true);

        expect(provider.drinks.length, 1);
        expect(provider.drinks[0].name, equals('Clean Ale'));
      });

      test('clearAllergenFilters removes all allergen filters', () async {
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [glutenDrink, cleanDrink]);
        await provider.loadDrinks();

        await provider.setAllergenFilter('gluten', active: true);
        expect(provider.drinks.length, 1);

        await provider.clearAllergenFilters();
        expect(provider.drinks.length, 2);
        expect(provider.excludedAllergens, isEmpty);
      });

      test(
        'setAllergenFilter false removes allergen from exclusion set',
        () async {
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => [glutenDrink, cleanDrink]);
          await provider.loadDrinks();

          await provider.setAllergenFilter('gluten', active: true);
          expect(provider.drinks.length, 1);

          await provider.setAllergenFilter('gluten', active: false);
          expect(provider.drinks.length, 2);
          expect(provider.excludedAllergens, isEmpty);
        },
      );

      test('clearVisibilityFilters removes all visibility filters', () async {
        await provider.setVisibilityFilter(
          DrinkVisibilityFilter.availableOnly,
          active: true,
        );
        await provider.setVisibilityFilter(
          DrinkVisibilityFilter.notTasted,
          active: true,
        );
        expect(provider.visibilityFilters.length, 2);

        await provider.clearVisibilityFilters();
        expect(provider.visibilityFilters, isEmpty);
        expect(provider.hideUnavailable, isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('visibilityFilters'), isEmpty);
      });

      test(
        'excludedAllergens persisted and restored on initialization',
        () async {
          await provider.setAllergenFilter('gluten', active: true);
          await provider.setAllergenFilter('sulphites', active: true);

          final prefs = await SharedPreferences.getInstance();
          expect(
            prefs.getStringList('excludedAllergens'),
            containsAll(['gluten', 'sulphites']),
          );

          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();
          expect(
            provider.excludedAllergens,
            containsAll(['gluten', 'sulphites']),
          );
        },
      );
    });

    group('getDrinkById', () {
      test('returns drink when found', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        final drink = provider.getDrinkById('drink-1');
        expect(drink, isNotNull);
        expect(drink!.name, 'Alpha Ale');
      });

      test('returns null when not found', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        final drink = provider.getDrinkById('non-existent');
        expect(drink, isNull);
      });
    });

    group('hasFestivals', () {
      test('returns false when no festivals loaded', () {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        expect(provider.hasFestivals, isFalse);
      });

      test('returns true when festivals are loaded', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        when(mockFestivalRepository.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [
              const Festival(
                id: 'test',
                name: 'Test Festival',
                dataBaseUrl: 'https://example.com',
              ),
            ],
            defaultFestivalId: 'test',
            baseUrl: 'https://example.com',
            version: '1.0.0',
          ),
        );
        when(
          mockFestivalRepository.getSelectedFestivalId(),
        ).thenAnswer((_) async => null);

        await provider.loadFestivals();
        expect(provider.hasFestivals, isTrue);
      });
    });

    group('registry refresh updates current festival (#306)', () {
      void stubRegistry(Festival festival) {
        when(mockFestivalRepository.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [festival],
            defaultFestivalId: festival.id,
            baseUrl: 'https://example.com',
            version: '1.0.0',
          ),
        );
      }

      test(
        'refreshes current festival metadata even when the id is unchanged',
        () async {
          // A non-beverage field (name) changing in the registry should be
          // reflected, but it must not trigger a needless drinks refetch.
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );

          stubRegistry(createSampleFestival(name: 'Old Name'));
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());

          await provider.initialize();
          await provider.loadDrinks();
          expect(provider.currentFestival.name, 'Old Name');

          stubRegistry(createSampleFestival(name: 'New Name'));
          clearInteractions(mockDrinkRepository);

          await provider.loadFestivals();
          await pumpEventQueue();

          expect(provider.currentFestival.name, 'New Name');
          verifyNever(mockDrinkRepository.getDrinks(any));
        },
      );

      test(
        'refreshes reference and refetches drinks when beverage types change',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );

          stubRegistry(
            createSampleFestival(availableBeverageTypes: const ['beer']),
          );
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());

          await provider.initialize();
          await provider.loadDrinks();
          expect(provider.currentFestival.availableBeverageTypes, ['beer']);

          // The live registry now advertises an extra beverage type for the
          // same festival id.
          stubRegistry(
            createSampleFestival(
              availableBeverageTypes: const ['beer', 'cider'],
            ),
          );
          clearInteractions(mockDrinkRepository);

          await provider.loadFestivals();
          await pumpEventQueue();

          // Reference is repointed at the fresh festival...
          expect(
            provider.currentFestival.availableBeverageTypes,
            containsAll(<String>['beer', 'cider']),
          );
          // ...and drinks were refetched against the updated festival, so the
          // newly-added type is actually loaded this session.
          final captured = verify(
            mockDrinkRepository.getDrinks(captureAny),
          ).captured.cast<Festival>();
          expect(captured.last.availableBeverageTypes, contains('cider'));
        },
      );

      test(
        'does not refetch drinks when beverage types are unchanged',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );

          stubRegistry(
            createSampleFestival(
              availableBeverageTypes: const ['beer', 'cider'],
            ),
          );
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());

          await provider.initialize();
          await provider.loadDrinks();

          // Registry refresh returns the same beverage types with the order
          // swapped, proving the comparison is set-based not order-sensitive.
          stubRegistry(
            createSampleFestival(
              availableBeverageTypes: const ['cider', 'beer'],
            ),
          );
          clearInteractions(mockDrinkRepository);

          await provider.loadFestivals();
          await pumpEventQueue();

          verifyNever(mockDrinkRepository.getDrinks(any));
        },
      );

      test('ignores registry updates for an unrelated festival id', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        stubRegistry(createSampleFestival(id: 'cbf2025'));
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());

        await provider.initialize();
        await provider.loadDrinks();
        expect(provider.currentFestival.id, 'cbf2025');

        // The registry no longer lists the selected festival; a different one
        // appears in its place.
        stubRegistry(
          createSampleFestival(
            id: 'cbf2024',
            availableBeverageTypes: const ['beer', 'cider'],
          ),
        );
        clearInteractions(mockDrinkRepository);

        await provider.loadFestivals();
        await pumpEventQueue();

        // Selection is left untouched and no refetch is triggered.
        expect(provider.currentFestival.id, 'cbf2025');
        expect(provider.currentFestival.availableBeverageTypes, ['beer']);
        verifyNever(mockDrinkRepository.getDrinks(any));
      });
    });

    group('combined filters', () {
      test('applies category and style filters together', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider
          ..setCategory('beer')
          ..toggleStyle('IPA');

        expect(provider.drinks.length, 1);
        expect(provider.drinks.first.name, 'Alpha Ale');
      });

      test('applies category, style, and search together', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider
          ..setCategory('beer')
          ..setSearchQuery('alpha');

        expect(provider.drinks.length, 1);
        expect(provider.drinks.first.name, 'Alpha Ale');
      });
    });

    group('festival persistence', () {
      test('setFestival persists festival ID to storage', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        when(mockFestivalRepository.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [
              const Festival(
                id: 'cbf2024',
                name: 'Cambridge 2024',
                dataBaseUrl: 'https://example.com/cbf2024',
              ),
              const Festival(
                id: 'cbf2025',
                name: 'Cambridge 2025',
                dataBaseUrl: 'https://example.com/cbf2025',
              ),
            ],
            defaultFestivalId: 'cbf2025',
            baseUrl: 'https://example.com',
            version: '1.0.0',
          ),
        );
        when(
          mockFestivalRepository.getSelectedFestivalId(),
        ).thenAnswer((_) async => null);

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => <Drink>[]);

        // Mock setSelectedFestivalId to actually save to SharedPreferences
        when(mockFestivalRepository.setSelectedFestivalId(any)).thenAnswer((
          invocation,
        ) async {
          final festivalId = invocation.positionalArguments[0] as String;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selected_festival_id', festivalId);
        });

        await provider.initialize();

        final festival2024 = provider.festivals.firstWhere(
          (f) => f.id == 'cbf2024',
        );
        await provider.setFestival(festival2024);

        final prefs = await SharedPreferences.getInstance();
        final savedId = prefs.getString('selected_festival_id');

        expect(savedId, 'cbf2024');
      });

      test(
        'setFestival does not wait for analytics before continuing',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );

          await provider.initialize();

          final analyticsCompleter = Completer<void>();
          when(
            mockAnalyticsService.logFestivalSelected(any),
          ).thenAnswer((_) => analyticsCompleter.future);

          final festival2024 = DefaultFestivals.cambridge2024;
          await provider
              .setFestival(festival2024)
              .timeout(const Duration(milliseconds: 200));

          verify(
            mockFestivalRepository.setSelectedFestivalId(festival2024.id),
          ).called(1);
          analyticsCompleter.complete();
        },
      );

      test('initialize restores previously selected festival', () async {
        // Pre-populate SharedPreferences with a saved festival
        SharedPreferences.setMockInitialValues({
          'selected_festival_id': 'cbf2024',
        });

        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        when(mockFestivalRepository.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [
              const Festival(
                id: 'cbf2024',
                name: 'Cambridge 2024',
                dataBaseUrl: 'https://example.com/cbf2024',
              ),
              const Festival(
                id: 'cbf2025',
                name: 'Cambridge 2025',
                dataBaseUrl: 'https://example.com/cbf2025',
              ),
            ],
            defaultFestivalId: 'cbf2025',
            baseUrl: 'https://example.com',
            version: '1.0.0',
          ),
        );
        // Mock getSelectedFestivalId to read from SharedPreferences
        when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((
          _,
        ) async {
          final prefs = await SharedPreferences.getInstance();
          return prefs.getString('selected_festival_id');
        });

        await provider.initialize();

        expect(provider.currentFestival.id, 'cbf2024');
        expect(provider.currentFestival.name, 'Cambridge 2024');
      });

      test('falls back to default when saved festival not found', () async {
        // Pre-populate SharedPreferences with a non-existent festival
        SharedPreferences.setMockInitialValues({
          'selected_festival_id': 'non-existent',
        });

        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        when(mockFestivalRepository.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [
              const Festival(
                id: 'cbf2025',
                name: 'Cambridge 2025',
                dataBaseUrl: 'https://example.com/cbf2025',
              ),
            ],
            defaultFestivalId: 'cbf2025',
            baseUrl: 'https://example.com',
            version: '1.0.0',
          ),
        );
        when(
          mockFestivalRepository.getSelectedFestivalId(),
        ).thenAnswer((_) async => null);

        await provider.initialize();

        expect(provider.currentFestival.id, 'cbf2025');
      });

      test('works correctly when no festival was previously saved', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        when(mockFestivalRepository.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [
              const Festival(
                id: 'cbf2025',
                name: 'Cambridge 2025',
                dataBaseUrl: 'https://example.com/cbf2025',
              ),
            ],
            defaultFestivalId: 'cbf2025',
            baseUrl: 'https://example.com',
            version: '1.0.0',
          ),
        );
        when(
          mockFestivalRepository.getSelectedFestivalId(),
        ).thenAnswer((_) async => null);

        await provider.initialize();

        expect(provider.currentFestival.id, 'cbf2025');
      });
    });

    group('festival switch race condition', () {
      test(
        'rapid festival switches show only last-selected festival drinks',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );

          const festivalA = Festival(
            id: 'cbf2024',
            name: 'Cambridge 2024',
            dataBaseUrl: 'https://example.com/cbf2024',
          );
          const festivalB = Festival(
            id: 'cbf2025',
            name: 'Cambridge 2025',
            dataBaseUrl: 'https://example.com/cbf2025',
          );
          // festivalC is the default so that setFestival(A) doesn't hit the
          // early-return guard (_currentFestival?.id == festival.id) and both
          // race competitors actually initiate a getDrinks call.
          const festivalC = Festival(
            id: 'cbf2023',
            name: 'Cambridge 2023',
            dataBaseUrl: 'https://example.com/cbf2023',
          );

          when(mockFestivalRepository.getFestivals()).thenAnswer(
            (_) async => FestivalsResponse(
              festivals: [festivalA, festivalB, festivalC],
              defaultFestivalId: 'cbf2023',
              baseUrl: 'https://example.com',
              version: '1.0.0',
            ),
          );
          when(
            mockFestivalRepository.getSelectedFestivalId(),
          ).thenAnswer((_) async => null);

          final producerA = Producer.fromJson({
            'id': 'brewery-a',
            'name': 'Brewery A',
            'location': 'City',
            'products': [],
          });
          final producerB = Producer.fromJson({
            'id': 'brewery-b',
            'name': 'Brewery B',
            'location': 'City',
            'products': [],
          });
          final drinkA = Drink(
            product: Product.fromJson({
              'id': 'drink-a',
              'name': 'Ale A',
              'category': 'beer',
              'dispense': 'cask',
              'abv': '4.0',
            }),
            producer: producerA,
            festivalId: 'cbf2024',
          );
          final drinkB = Drink(
            product: Product.fromJson({
              'id': 'drink-b',
              'name': 'Ale B',
              'category': 'beer',
              'dispense': 'cask',
              'abv': '5.0',
            }),
            producer: producerB,
            festivalId: 'cbf2025',
          );

          // Festival A's load is slow; B's is instant
          when(mockDrinkRepository.getDrinks(any)).thenAnswer((
            invocation,
          ) async {
            final festival = invocation.positionalArguments[0] as Festival;
            if (festival.id == 'cbf2024') {
              await Future.delayed(const Duration(milliseconds: 100));
              return [drinkA];
            }
            return [drinkB];
          });

          await provider.initialize();

          // Switch to A (slow), then immediately to B (fast) — don't await A
          final futureA = provider.setFestival(festivalA);
          final futureB = provider.setFestival(festivalB);
          await Future.wait([futureA, futureB]);

          // B's result must win; A's stale response must be discarded
          expect(provider.currentFestival.id, 'cbf2025');
          expect(provider.drinks.length, 1);
          expect(provider.drinks.first.name, 'Ale B');
          expect(provider.isLoading, isFalse);
        },
      );
    });

    group('automatic refresh', () {
      test('isDrinksDataStale returns true when no data loaded', () {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        expect(provider.isDrinksDataStale, isTrue);
      });

      test('isFestivalsDataStale returns true when no festivals loaded', () {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        expect(provider.isFestivalsDataStale, isTrue);
      });

      test(
        'isDrinksDataStale returns false immediately after loading drinks',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          final sampleDrinks = createSampleDrinks();
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => sampleDrinks);

          await provider.loadDrinks();

          expect(provider.isDrinksDataStale, isFalse);
        },
      );

      test(
        'isFestivalsDataStale returns false immediately after loading festivals',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );

          when(mockFestivalRepository.getFestivals()).thenAnswer(
            (_) async => FestivalsResponse(
              festivals: [
                const Festival(
                  id: 'cbf2025',
                  name: 'Cambridge 2025',
                  dataBaseUrl: 'https://example.com/cbf2025',
                ),
              ],
              defaultFestivalId: 'cbf2025',
              baseUrl: 'https://example.com',
              version: '1.0.0',
            ),
          );
          when(
            mockFestivalRepository.getSelectedFestivalId(),
          ).thenAnswer((_) async => null);

          await provider.loadFestivals();

          expect(provider.isFestivalsDataStale, isFalse);
        },
      );

      test('refreshIfStale does nothing when already loading', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        when(mockFestivalRepository.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [
              const Festival(
                id: 'cbf2025',
                name: 'Cambridge 2025',
                dataBaseUrl: 'https://example.com/cbf2025',
              ),
            ],
            defaultFestivalId: 'cbf2025',
            baseUrl: 'https://example.com',
            version: '1.0.0',
          ),
        );
        when(
          mockFestivalRepository.getSelectedFestivalId(),
        ).thenAnswer((_) async => null);

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());

        await provider.initialize();

        // Reset mocks to track only the calls we care about
        reset(mockDrinkRepository);
        reset(mockFestivalRepository);

        var loadCallCount = 0;
        when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async {
          loadCallCount++;
          // Simulate slow network
          await Future.delayed(const Duration(milliseconds: 100));
          return createSampleDrinks();
        });

        when(mockFestivalRepository.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [
              const Festival(
                id: 'cbf2025',
                name: 'Cambridge 2025',
                dataBaseUrl: 'https://example.com/cbf2025',
              ),
            ],
            defaultFestivalId: 'cbf2025',
            baseUrl: 'https://example.com',
            version: '1.0.0',
          ),
        );
        when(
          mockFestivalRepository.getSelectedFestivalId(),
        ).thenAnswer((_) async => null);

        // Start loading (don't await)
        final loadFuture = provider.loadDrinks();

        // Call refreshIfStale while loading is in progress
        await provider.refreshIfStale();

        // Wait for original load to complete
        await loadFuture;

        // Should only have been called once (the original loadDrinks)
        expect(loadCallCount, 1);
      });

      test('refreshIfStale does not refresh when data is fresh', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        when(mockFestivalRepository.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [
              const Festival(
                id: 'cbf2025',
                name: 'Cambridge 2025',
                dataBaseUrl: 'https://example.com/cbf2025',
              ),
            ],
            defaultFestivalId: 'cbf2025',
            baseUrl: 'https://example.com',
            version: '1.0.0',
          ),
        );
        when(
          mockFestivalRepository.getSelectedFestivalId(),
        ).thenAnswer((_) async => null);

        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => sampleDrinks);

        await provider.loadDrinks();

        // Reset mock to track subsequent calls
        reset(mockDrinkRepository);
        reset(mockFestivalRepository);

        // Call refreshIfStale with fresh data
        await provider.refreshIfStale();

        // Should not have called either service since data is fresh
        verifyNever(mockDrinkRepository.getDrinks(any));
        verifyNever(mockFestivalRepository.getFestivals());
      });

      test('setFestival updates timestamp', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );

        when(mockFestivalRepository.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [
              const Festival(
                id: 'cbf2024',
                name: 'Cambridge 2024',
                dataBaseUrl: 'https://example.com/cbf2024',
              ),
              const Festival(
                id: 'cbf2025',
                name: 'Cambridge 2025',
                dataBaseUrl: 'https://example.com/cbf2025',
              ),
            ],
            defaultFestivalId: 'cbf2025',
            baseUrl: 'https://example.com',
            version: '1.0.0',
          ),
        );
        when(
          mockFestivalRepository.getSelectedFestivalId(),
        ).thenAnswer((_) async => null);

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());

        await provider.initialize();
        await provider.loadDrinks();

        // Data should be fresh
        expect(provider.isDrinksDataStale, isFalse);

        // Change festival (which loads drinks internally)
        final festival2024 = provider.festivals.firstWhere(
          (f) => f.id == 'cbf2024',
        );
        await provider.setFestival(festival2024);

        // Data should still be fresh after festival change
        expect(provider.isDrinksDataStale, isFalse);
      });

      test(
        'loadFestivals stamps attempt timestamp even when network fails',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          when(
            mockFestivalRepository.getFestivals(),
          ).thenThrow(Exception('offline'));
          when(
            mockFestivalRepository.getCachedFestivals(),
          ).thenAnswer((_) async => null);

          expect(provider.lastFestivalsRefreshAttempt, isNull);
          await provider.loadFestivals();
          expect(provider.lastFestivalsRefreshAttempt, isNotNull);
        },
      );

      test(
        'refreshIfStale skips festivals retry when last attempt was recent',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          when(
            mockFestivalRepository.getFestivals(),
          ).thenThrow(Exception('offline'));
          when(
            mockFestivalRepository.getCachedFestivals(),
          ).thenAnswer((_) async => null);

          // First attempt fails and stamps the attempt timestamp.
          await provider.loadFestivals();
          expect(provider.isFestivalsDataStale, isTrue);

          reset(mockFestivalRepository);

          // Suppress drinks retry too: loadDrinks() would internally call
          // loadFestivals() when _currentFestival is null and _festivals is empty.
          provider.lastDrinksRefreshAttempt = DateTime.now();

          // Immediate retry via refreshIfStale must be suppressed.
          await provider.refreshIfStale();
          verifyNever(mockFestivalRepository.getFestivals());
        },
      );

      test(
        'refreshIfStale retries festivals when last attempt is past threshold',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          when(
            mockFestivalRepository.getFestivals(),
          ).thenThrow(Exception('offline'));
          when(
            mockFestivalRepository.getCachedFestivals(),
          ).thenAnswer((_) async => null);

          provider
            // Simulate a stale attempt by backdating the timestamp.
            ..lastFestivalsRefreshAttempt = DateTime.now().subtract(
              const Duration(minutes: 2),
            )
            // Suppress drinks retry so loadDrinks() doesn't re-trigger loadFestivals().
            ..lastDrinksRefreshAttempt = DateTime.now();

          expect(provider.isFestivalsDataStale, isTrue);

          await provider.refreshIfStale();
          verify(mockFestivalRepository.getFestivals()).called(1);
        },
      );

      test(
        '_refreshDrinksFromNetwork stamps attempt timestamp even when network fails',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();
          when(
            mockDrinkRepository.getCachedDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenThrow(Exception('offline'));

          expect(provider.lastDrinksRefreshAttempt, isNull);
          await provider.loadDrinks();
          expect(provider.lastDrinksRefreshAttempt, isNotNull);
        },
      );

      test(
        'refreshIfStale skips drinks retry when last attempt was recent',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();
          when(
            mockDrinkRepository.getCachedDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenThrow(Exception('offline'));

          // First attempt fails and stamps the attempt timestamp.
          await provider.loadDrinks();
          expect(provider.isDrinksDataStale, isTrue);

          reset(mockDrinkRepository);

          // Immediate retry via refreshIfStale must be suppressed.
          await provider.refreshIfStale();
          verifyNever(mockDrinkRepository.getDrinks(any));
        },
      );

      test(
        'refreshIfStale retries drinks when last attempt is past threshold',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();
          when(
            mockDrinkRepository.getCachedDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenThrow(Exception('offline'));

          // Simulate a stale attempt by backdating the attempt timestamp.
          provider.lastDrinksRefreshAttempt = DateTime.now().subtract(
            const Duration(minutes: 2),
          );

          expect(provider.isDrinksDataStale, isTrue);

          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          await provider.refreshIfStale();
          verify(mockDrinkRepository.getDrinks(any)).called(1);
        },
      );

      test(
        'does not update lastDrinksRefresh when festival has no beverage types',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);

          final emptyFestival = createSampleFestival(
            id: 'cbf-empty',
            availableBeverageTypes: [],
          );
          await provider.setFestival(emptyFestival, persist: false);

          expect(provider.isDrinksDataStale, isTrue);
          expect(provider.lastDrinksRefresh, isNull);
        },
      );

      test(
        'resets lastDrinksRefresh when switching to a festival with no types',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);

          // Load a normal festival first to set _lastDrinksRefresh.
          await provider.loadDrinks();
          expect(provider.lastDrinksRefresh, isNotNull);

          // Switch to a festival with no types — timestamp must be cleared.
          final emptyFestival = createSampleFestival(
            id: 'cbf-empty',
            availableBeverageTypes: [],
          );
          await provider.setFestival(emptyFestival, persist: false);

          expect(provider.lastDrinksRefresh, isNull);
          expect(provider.isDrinksDataStale, isTrue);
        },
      );

      test(
        'updates lastDrinksRefresh when festival has beverage types',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);
          await provider.loadDrinks();

          expect(provider.lastDrinksRefresh, isNotNull);
          expect(provider.isDrinksDataStale, isFalse);
        },
      );
    });

    group('tasted, refresh and favourite filtering', () {
      test('toggleTasted updates the drink and logs the change', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());
        await provider.loadDrinks();
        final drink = provider.allDrinks.first;

        when(mockDrinkRepository.toggleTasted(any, any)).thenAnswer(
          (_) async => UserDrinkState(
            tastingEvents: [DateTime.now()],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await provider.toggleTasted(drink);
        expect(provider.getDrinkById(drink.id)!.isTasted, isTrue);
        verify(mockAnalyticsService.logTastedAdded(drink)).called(1);

        when(
          mockDrinkRepository.toggleTasted(any, any),
        ).thenAnswer((_) async => null);
        final drink2 = provider.getDrinkById(drink.id)!;
        await provider.toggleTasted(drink2);
        expect(provider.getDrinkById(drink.id)!.isTasted, isFalse);
        verify(mockAnalyticsService.logTastedRemoved(drink2)).called(1);
      });

      test(
        'clearing the last bit of user state nulls out userState in memory',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          await provider.loadDrinks();
          final drink = provider.allDrinks.first;

          // Turn tasted on: the in-memory record now carries a single event.
          when(mockDrinkRepository.toggleTasted(any, any)).thenAnswer(
            (_) async => UserDrinkState(
              tastingEvents: [DateTime.now()],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          await provider.toggleTasted(drink);
          expect(provider.getDrinkById(drink.id)!.userState, isNotNull);

          // Turn it back off: the record is now empty, so userState must be
          // null to mirror the store, which prunes empty records.
          when(
            mockDrinkRepository.toggleTasted(any, any),
          ).thenAnswer((_) async => null);
          await provider.toggleTasted(provider.getDrinkById(drink.id)!);
          expect(provider.getDrinkById(drink.id)!.userState, isNull);
        },
      );

      test(
        'refreshIfStale reloads festivals and drinks when both are stale',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());

          // Without initialize()/loadDrinks() both refresh timestamps are null,
          // so both data sets report as stale.
          expect(provider.isFestivalsDataStale, isTrue);
          expect(provider.isDrinksDataStale, isTrue);

          await provider.refreshIfStale();

          verify(mockFestivalRepository.getFestivals()).called(1);
          verify(mockDrinkRepository.getDrinks(any)).called(1);
          expect(provider.allDrinks, isNotEmpty);
        },
      );

      test(
        'refreshIfStale skips a duplicate fetch while SWR refresh in flight',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          // Cache renders instantly; the network refresh hangs so isRefreshing
          // stays true while we attempt a resume-triggered refreshIfStale.
          when(
            mockDrinkRepository.getCachedDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          final pending = Completer<List<Drink>>();
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) => pending.future);

          final firstLoad = provider.loadDrinks();
          await Future<void>.delayed(Duration.zero);
          expect(provider.isRefreshing, isTrue);

          // refreshIfStale while a refresh is mid-flight must not kick a second
          // getDrinks call — _isRefreshing guards against the duplicate.
          await provider.refreshIfStale();
          verify(mockDrinkRepository.getDrinks(any)).called(1);

          pending.complete(createSampleDrinks());
          await firstLoad;
        },
      );

      test(
        'setFestival on the current festival retries when a notice is up',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          // Get into the "showing saved data" state.
          when(
            mockDrinkRepository.getCachedDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenThrow(TimeoutException('offline'));
          await provider.loadDrinks();
          expect(provider.refreshNotice, isNotNull);
          clearInteractions(mockDrinkRepository);

          // Re-tapping the current festival in the switcher must fire a retry.
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          await provider.setFestival(provider.currentFestival);

          verify(mockDrinkRepository.getDrinks(any)).called(1);
          expect(provider.refreshNotice, isNull);
        },
      );

      test('initialize ignores a retired saved festival id rather than '
          'resurrecting it from DefaultFestivals', () async {
        // Saved id matches an active DefaultFestival but no longer exists in
        // the live registry; the user should land on the registry default,
        // not on a defunct hard-coded festival whose URL would 404.
        final retired = DefaultFestivals.all.first;
        SharedPreferences.setMockInitialValues({
          'selected_festival_id': retired.id,
        });
        final liveFestival = Festival(
          id: '${retired.id}-successor',
          name: 'Successor Festival',
          dataBaseUrl: 'https://example.com/successor',
        );
        when(mockFestivalRepository.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [liveFestival],
            defaultFestivalId: liveFestival.id,
            baseUrl: 'https://example.com',
            version: '1.0.0',
          ),
        );
        when(
          mockFestivalRepository.getSelectedFestivalId(),
        ).thenAnswer((_) async => retired.id);
        when(
          mockFestivalRepository.getCachedFestivals(),
        ).thenAnswer((_) async => null);

        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        expect(provider.currentFestival.id, liveFestival.id);
      });

      test(
        'toggleFavorite re-applies filters when showing favourites only',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          await provider.loadDrinks();

          provider.setShowFavoritesOnly(value: true);
          expect(provider.showFavoritesOnly, isTrue);
          expect(provider.drinks, isEmpty);

          final drink = provider.allDrinks.first;
          when(mockDrinkRepository.toggleFavorite(any, any)).thenAnswer(
            (_) async => UserDrinkState(
              wantToTry: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          await provider.toggleFavorite(drink);

          // The favourites-only list is refreshed by toggleFavorite.
          expect(provider.drinks.any((d) => d.id == drink.id), isTrue);
        },
      );

      test('styleCountsMap is scoped to the selected category', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());
        await provider.loadDrinks();

        expect(
          provider.styleCountsMap.keys,
          containsAll(['IPA', 'Bitter', 'Dry', 'Sweet']),
        );

        provider.setCategory('cider');
        expect(provider.styleCountsMap.keys, containsAll(['Dry', 'Sweet']));
        expect(provider.styleCountsMap.containsKey('IPA'), isFalse);
      });

      test('lastDrinksRefresh is set only after a successful load', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();
        expect(provider.lastDrinksRefresh, isNull);

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());
        await provider.loadDrinks();

        expect(provider.lastDrinksRefresh, isNotNull);
      });

      test(
        'addTasting updates the drink userState and logs mark_tasted',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          await provider.loadDrinks();
          final drink = provider.allDrinks.first;

          when(
            mockDrinkRepository.addTasting(any, any, now: anyNamed('now')),
          ).thenAnswer(
            (_) async => UserDrinkState(
              tastingEvents: [DateTime.now()],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          await provider.addTasting(drink);
          final updatedDrink = provider.getDrinkById(drink.id)!;
          expect(updatedDrink.userState!.tastingCount, 1);
          verify(mockAnalyticsService.logFestivalLogMarkTasted(any)).called(1);
          verifyNever(
            mockAnalyticsService.logFestivalLogMultipleTasting(any, any),
          );
        },
      );

      test(
        'addTasting logs multiple_tasting only when count exceeds one',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          await provider.loadDrinks();
          final drink = provider.allDrinks.first;

          when(
            mockDrinkRepository.addTasting(any, any, now: anyNamed('now')),
          ).thenAnswer(
            (_) async => UserDrinkState(
              tastingEvents: [
                DateTime.now(),
                DateTime.now().add(const Duration(hours: 1)),
              ],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          await provider.addTasting(drink);
          verify(mockAnalyticsService.logFestivalLogMarkTasted(any)).called(1);
          verify(
            mockAnalyticsService.logFestivalLogMultipleTasting(any, 2),
          ).called(1);
        },
      );

      test(
        'removeTasting updates the drink userState and logs delete_timestamp',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();
          final eventTime = DateTime.now();
          // Seed the drink with an existing tasting so the removal is a real
          // decrement, not a no-op.
          final sample = createSampleDrinks();
          final tasted = sample.first.copyWith(
            userState: UserDrinkState(
              tastingEvents: [eventTime],
              createdAt: eventTime,
              updatedAt: eventTime,
            ),
          );
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => [tasted, ...sample.skip(1)]);
          await provider.loadDrinks();
          final drink = provider.allDrinks.first;

          when(mockDrinkRepository.removeTasting(any, any, any)).thenAnswer(
            (_) async => UserDrinkState(
              wantToTry: true,
              tastingEvents: const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          await provider.removeTasting(drink, eventTime);
          final updatedDrink = provider.getDrinkById(drink.id)!;
          expect(updatedDrink.userState!.isTasted, isFalse);
          expect(updatedDrink.userState!.wantToTry, isTrue);
          verify(
            mockAnalyticsService.logFestivalLogDeleteTimestamp(any),
          ).called(1);
        },
      );

      test('removeTasting does not log when nothing was removed', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();
        final eventTime = DateTime.now();
        final sample = createSampleDrinks();
        final tasted = sample.first.copyWith(
          userState: UserDrinkState(
            tastingEvents: [eventTime],
            createdAt: eventTime,
            updatedAt: eventTime,
          ),
        );
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [tasted, ...sample.skip(1)]);
        await provider.loadDrinks();
        final drink = provider.allDrinks.first;

        // Repository is a no-op (event not found): returns the state unchanged,
        // so the tasting count does not decrease and no delete is logged.
        when(mockDrinkRepository.removeTasting(any, any, any)).thenAnswer(
          (_) async => UserDrinkState(
            tastingEvents: [eventTime],
            createdAt: eventTime,
            updatedAt: eventTime,
          ),
        );
        await provider.removeTasting(drink, DateTime(2000));
        verifyNever(mockAnalyticsService.logFestivalLogDeleteTimestamp(any));
      });

      test('removeTasting with pruned record clears userState', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());
        await provider.loadDrinks();
        final drink = provider.allDrinks.first;

        final eventTime = DateTime.now();
        when(
          mockDrinkRepository.removeTasting(any, any, any),
        ).thenAnswer((_) async => null);
        await provider.removeTasting(drink, eventTime);
        final updatedDrink = provider.getDrinkById(drink.id)!;
        expect(updatedDrink.userState, isNull);
      });

      test('setUserNotes persists notes onto the drink', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());
        await provider.loadDrinks();
        final drink = provider.allDrinks.first;

        when(mockDrinkRepository.setUserNotes(any, any, any)).thenAnswer(
          (_) async => UserDrinkState(
            notes: 'Great with cheese',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await provider.setUserNotes(drink, 'Great with cheese');
        final updatedDrink = provider.getDrinkById(drink.id)!;
        expect(updatedDrink.userState!.notes, 'Great with cheese');
      });

      test('toggleFavorite logs festival_log_add_to_try when adding', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());
        await provider.loadDrinks();
        final drink = provider.allDrinks.first;

        when(mockDrinkRepository.toggleFavorite(any, any)).thenAnswer(
          (_) async => UserDrinkState(
            wantToTry: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await provider.toggleFavorite(drink);
        verify(mockAnalyticsService.logFestivalLogAddToTry(any)).called(1);
      });
    });

    group('stale-while-revalidate', () {
      test(
        'shows cached drinks and surfaces a notice when refresh fails',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          when(
            mockDrinkRepository.getCachedDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenThrow(BeerApiException('boom', 500));

          await provider.loadDrinks();

          // Cached data stays on screen; no blocking error, just a quiet notice.
          expect(provider.drinks, isNotEmpty);
          expect(provider.error, isNull);
          expect(provider.refreshNotice, isNotNull);
          expect(provider.isRefreshing, isFalse);
        },
      );

      test(
        'logs non-connectivity refresh failures even with cached data',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          when(
            mockDrinkRepository.getCachedDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          final error = BeerApiException('server', 500);
          when(mockDrinkRepository.getDrinks(any)).thenThrow(error);

          await provider.loadDrinks();

          // A server/parse error is a real bug that the cache would otherwise
          // mask, so it must still be logged (catches "silent never-load").
          verify(
            mockAnalyticsService.logError(
              error,
              any,
              reason: anyNamed('reason'),
            ),
          ).called(1);
        },
      );

      test('does not log offline refresh failures covered by cache', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        when(
          mockDrinkRepository.getCachedDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenThrow(TimeoutException('offline'));

        await provider.loadDrinks();

        expect(provider.refreshNotice, isNotNull);
        verifyNever(
          mockAnalyticsService.logError(any, any, reason: anyNamed('reason')),
        );
      });

      test(
        'does not log when BeerApiException wraps a connectivity cause',
        () async {
          // When every beverage type fails offline, the repository throws a
          // BeerApiException whose `cause` carries one of the underlying network
          // errors. _isConnectivityError must unwrap it so analytics stays quiet
          // for the offline-with-cache case (not just the raw TimeoutException).
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          when(
            mockDrinkRepository.getCachedDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          when(mockDrinkRepository.getDrinks(any)).thenThrow(
            BeerApiException(
              'Failed to load any drinks...',
              null,
              TimeoutException('offline'),
            ),
          );

          await provider.loadDrinks();

          expect(provider.refreshNotice, isNotNull);
          verifyNever(
            mockAnalyticsService.logError(any, any, reason: anyNamed('reason')),
          );
        },
      );

      test('shows error when refresh fails and there is no cache', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        when(
          mockDrinkRepository.getCachedDrinks(any),
        ).thenAnswer((_) async => null);
        final error = TimeoutException('offline');
        when(mockDrinkRepository.getDrinks(any)).thenThrow(error);

        await provider.loadDrinks();

        expect(provider.drinks, isEmpty);
        expect(provider.error, isNotNull);
        expect(provider.refreshNotice, isNull);
        // Fully blocked loads are always logged, even when offline.
        verify(
          mockAnalyticsService.logError(error, any, reason: anyNamed('reason')),
        ).called(1);
      });

      test(
        'loadDrinks does not wait for error analytics before updating state',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          when(
            mockDrinkRepository.getCachedDrinks(any),
          ).thenAnswer((_) async => null);
          final error = TimeoutException('offline');
          when(mockDrinkRepository.getDrinks(any)).thenThrow(error);

          final logErrorCompleter = Completer<void>();
          when(
            mockAnalyticsService.logError(any, any, reason: anyNamed('reason')),
          ).thenAnswer((_) => logErrorCompleter.future);

          await provider.loadDrinks().timeout(
            const Duration(milliseconds: 200),
          );

          expect(provider.error, isNotNull);
          expect(provider.isLoading, isFalse);
          expect(provider.isRefreshing, isFalse);
          logErrorCompleter.complete();
        },
      );

      test('successful refresh clears the notice and updates drinks', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        // First load shows cache then fails refresh -> notice set.
        when(
          mockDrinkRepository.getCachedDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenThrow(TimeoutException('offline'));
        await provider.loadDrinks();
        expect(provider.refreshNotice, isNotNull);

        // Second load succeeds -> notice cleared, drinks refreshed.
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());
        await provider.loadDrinks();

        expect(provider.refreshNotice, isNull);
        expect(provider.error, isNull);
        expect(provider.drinks, isNotEmpty);
      });

      test(
        'initialize populates festivals from cache without a network call',
        () async {
          when(mockFestivalRepository.getCachedFestivals()).thenAnswer(
            (_) async => FestivalsResponse(
              festivals: [DefaultFestivals.cambridge2025],
              defaultFestivalId: DefaultFestivals.cambridge2025.id,
              version: '1.0',
              baseUrl: 'https://data.cambeerfestival.app',
            ),
          );

          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          expect(provider.festivals, isNotEmpty);
          // Background refresh fires, but the cache populated the list first.
        },
      );

      test('dismissRefreshNotice clears the notice', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        when(
          mockDrinkRepository.getCachedDrinks(any),
        ).thenAnswer((_) async => createSampleDrinks());
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenThrow(TimeoutException('offline'));
        await provider.loadDrinks();
        expect(provider.refreshNotice, isNotNull);

        provider.dismissRefreshNotice();
        expect(provider.refreshNotice, isNull);
      });

      test(
        'setFestival shows the target festival cached drinks immediately',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          final other = DefaultFestivals.all.firstWhere(
            (f) => f.id != provider.currentFestival.id,
          );

          // Cached drinks available for the new festival; the network refresh
          // hangs so only the cache path has resolved when we assert.
          when(
            mockDrinkRepository.getCachedDrinks(any),
          ).thenAnswer((_) async => createSampleDrinks());
          final pending = Completer<List<Drink>>();
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) => pending.future);

          final future = provider.setFestival(other);
          await Future<void>.delayed(Duration.zero);

          expect(provider.currentFestival.id, other.id);
          expect(provider.drinks, isNotEmpty); // cached drinks shown
          expect(provider.isLoading, isFalse); // no blank spinner
          expect(provider.isRefreshing, isTrue); // background refresh running

          pending.complete(createSampleDrinks());
          await future;
          expect(provider.isRefreshing, isFalse);
        },
      );

      test(
        'setFestival shows a spinner when the target has no cache',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          final other = DefaultFestivals.all.firstWhere(
            (f) => f.id != provider.currentFestival.id,
          );

          when(
            mockDrinkRepository.getCachedDrinks(any),
          ).thenAnswer((_) async => null);
          final pending = Completer<List<Drink>>();
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) => pending.future);

          final future = provider.setFestival(other);
          await Future<void>.delayed(Duration.zero);

          expect(provider.drinks, isEmpty);
          expect(provider.isLoading, isTrue); // spinner until network resolves

          pending.complete(createSampleDrinks());
          await future;
          expect(provider.isLoading, isFalse);
          expect(provider.drinks, isNotEmpty);
        },
      );

      test(
        'loadFestivals falls back to cached festivals when network fails',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          when(
            mockFestivalRepository.getFestivals(),
          ).thenThrow(FestivalServiceException('boom', 500));
          when(mockFestivalRepository.getCachedFestivals()).thenAnswer(
            (_) async => FestivalsResponse(
              festivals: [DefaultFestivals.cambridge2025],
              defaultFestivalId: DefaultFestivals.cambridge2025.id,
              version: '1.0',
              baseUrl: 'https://data.cambeerfestival.app',
            ),
          );

          await provider.loadFestivals();

          // Switcher keeps working from cache; no error surfaced.
          expect(provider.festivals, isNotEmpty);
          expect(provider.festivalsError, isNull);
        },
      );

      test(
        'loadFestivals surfaces an error when network fails and no cache',
        () async {
          provider = BeerProvider(
            drinkRepository: mockDrinkRepository,
            festivalRepository: mockFestivalRepository,
            analyticsService: mockAnalyticsService,
          );
          await provider.initialize();

          when(
            mockFestivalRepository.getFestivals(),
          ).thenThrow(FestivalServiceException('boom', 500));
          when(
            mockFestivalRepository.getCachedFestivals(),
          ).thenAnswer((_) async => null);

          await provider.loadFestivals();

          expect(provider.festivals, isEmpty);
          expect(provider.festivalsError, isNotNull);
        },
      );
    });

    group('dispose', () {
      test('does not throw when repositories were injected', () {
        // Injected repos are never stored in _ownedXxx, so dispose() is a
        // no-op for them. Verify the whole call completes normally.
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        expect(() => provider.dispose(), returnsNormally);
        // Reset so tearDown disposes a fresh, un-disposed instance.
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
      });
    });
  });
}
