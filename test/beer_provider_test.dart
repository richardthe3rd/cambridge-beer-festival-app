import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/models/models.dart';
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

        expect(provider.currentFestival.id, 'cbf2025');
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);

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
        when(mockDrinkRepository.getDrinks(any))
            .thenThrow(BeerApiException('Error', 500));
        await provider.loadDrinks();
        expect(provider.error, isNotNull);

        // Then load successfully
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => <Drink>[]);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.toggleStyle('IPA');
        provider.toggleStyle('IPA');

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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.toggleStyle('IPA');
        provider.toggleStyle('Bitter');

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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.toggleStyle('IPA');
        provider.toggleStyle('Bitter');
        provider.clearStyles();

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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setSearchQuery('another');

        expect(provider.drinks.length, 2);
        expect(provider.drinks.every((d) => d.breweryName == 'Another Brewery'), isTrue);
      });

      test('setSearchQuery filters by style', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        // Toggle favorites after loading (simulates user action)
        await provider.toggleFavorite(provider.allDrinks[0]);
        await provider.toggleFavorite(provider.allDrinks[2]);

        provider.setShowFavoritesOnly(true);

        expect(provider.drinks.length, 2);
        expect(provider.drinks.every((d) => d.isFavorite), isTrue);
      });

      test('favoriteDrinks getter returns only favorites', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        // Toggle favorite after loading
        await provider.toggleFavorite(provider.allDrinks[0]);

        expect(provider.favoriteDrinks.length, 1);
        expect(provider.favoriteDrinks.first.name, 'Alpha Ale');
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
        
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        // Initially, all drinks should be visible
        expect(provider.drinks.length, 3);

        // Enable hide unavailable
        await provider.setHideUnavailable(true);

        // Sold out drink should be filtered out
        expect(provider.drinks.length, 2);
        expect(provider.drinks.any((d) => d.name == 'Sold Out Stout'), isFalse);
        expect(provider.drinks.any((d) => d.name == 'Available Ale'), isTrue);
        expect(provider.drinks.any((d) => d.name == 'Low Stock Lager'), isTrue);
      });

      test('setHideUnavailable filters out not yet available drinks', () async {
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
        
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        // Initially, both drinks should be visible
        expect(provider.drinks.length, 2);

        // Enable hide unavailable
        await provider.setHideUnavailable(true);

        // Not yet available drink should be filtered out
        expect(provider.drinks.length, 1);
        expect(provider.drinks.any((d) => d.name == 'Coming Soon Cider'), isFalse);
        expect(provider.drinks.any((d) => d.name == 'Available Ale'), isTrue);
      });

      test('setHideUnavailable persists preference', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        // Set hide unavailable
        await provider.setHideUnavailable(true);
        expect(provider.hideUnavailable, isTrue);

        // Verify it was persisted
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('hideUnavailable'), isTrue);

        // Disable it
        await provider.setHideUnavailable(false);
        expect(provider.hideUnavailable, isFalse);
        expect(prefs.getBool('hideUnavailable'), isFalse);
      });

      test('hideUnavailable preference is loaded on initialization', () async {
        // Set initial preference
        SharedPreferences.setMockInitialValues({'hideUnavailable': true});

        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        expect(provider.hideUnavailable, isTrue);
      });
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
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
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);

        await provider.loadFestivals();
        expect(provider.hasFestivals, isTrue);
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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setCategory('beer');
        provider.toggleStyle('IPA');

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
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);
        await provider.loadDrinks();

        provider.setCategory('beer');
        provider.setSearchQuery('alpha');

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
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);

        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => <Drink>[]);

        await provider.initialize();

        final festival2024 = provider.festivals.firstWhere((f) => f.id == 'cbf2024');
        await provider.setFestival(festival2024);

        final prefs = await SharedPreferences.getInstance();
        final savedId = prefs.getString('selected_festival_id');

        expect(savedId, 'cbf2024');
      });

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
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);

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
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);

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
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);

        await provider.initialize();

        expect(provider.currentFestival.id, 'cbf2025');
      });
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

      test('isDrinksDataStale returns false immediately after loading drinks', () async {
        provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);

        await provider.loadDrinks();

        expect(provider.isDrinksDataStale, isFalse);
      });

      test('isFestivalsDataStale returns false immediately after loading festivals', () async {
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
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);

        await provider.loadFestivals();

        expect(provider.isFestivalsDataStale, isFalse);
      });

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
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);

        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => createSampleDrinks());

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
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);

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
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);

        await provider.initialize();

        final sampleDrinks = createSampleDrinks();
        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => sampleDrinks);

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
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);

        when(mockDrinkRepository.getDrinks(any))
            .thenAnswer((_) async => createSampleDrinks());

        await provider.initialize();
        await provider.loadDrinks();

        // Data should be fresh
        expect(provider.isDrinksDataStale, isFalse);

        // Change festival (which loads drinks internally)
        final festival2024 = provider.festivals.firstWhere((f) => f.id == 'cbf2024');
        await provider.setFestival(festival2024);

        // Data should still be fresh after festival change
        expect(provider.isDrinksDataStale, isFalse);
      });
    });
  });
}
