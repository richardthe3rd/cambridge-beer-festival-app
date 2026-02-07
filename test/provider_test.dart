import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:http/http.dart' as http;
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/domain/models/models.dart';
import 'package:cambridge_beer_festival/domain/repositories/repositories.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<DrinkRepository>(),
  MockSpec<FestivalRepository>(),
  MockSpec<AnalyticsService>(),
])
void main() {
  group('BeerProvider Error Message Handling', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;

    setUp(() {
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();
      SharedPreferences.setMockInitialValues({});

      // Default mock behavior for initialize()
      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [DefaultFestivals.cambridge2025],
          defaultFestivalId: DefaultFestivals.cambridge2025.id,
          version: '1.0',
          baseUrl: 'https://data.cambeerfestival.app',
        ),
      );
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);
    });

    group('loadDrinks error messages', () {
      test('shows user-friendly message for 404 error', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
          festivalRepository: mockFestivalRepository,
          analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        // Mock 404 BeerApiException
        when(mockDrinkRepository.getDrinks(any))
            .thenThrow(BeerApiException('Not found', 404));

        await provider.loadDrinks();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('Festival data not found'));
        expect(provider.error, isNot(contains('BeerApiException')));
        expect(provider.error, isNot(contains('404')));
      });

      test('shows user-friendly message for 500 error', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        // Mock 500 BeerApiException
        when(mockDrinkRepository.getDrinks(any))
            .thenThrow(BeerApiException('Server error', 500));

        await provider.loadDrinks();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('Server error'));
        expect(provider.error, contains('try again later'));
        expect(provider.error, isNot(contains('BeerApiException')));
        expect(provider.error, isNot(contains('500')));
      });

      test('shows user-friendly message for 502 error', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        // Mock 502 BeerApiException (Bad Gateway)
        when(mockDrinkRepository.getDrinks(any))
            .thenThrow(BeerApiException('Bad Gateway', 502));

        await provider.loadDrinks();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('Server error'));
        expect(provider.error, contains('try again later'));
        expect(provider.error, isNot(contains('BeerApiException')));
        expect(provider.error, isNot(contains('502')));
      });

      test('shows user-friendly message for 503 error', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        // Mock 503 BeerApiException (Service Unavailable)
        when(mockDrinkRepository.getDrinks(any))
            .thenThrow(BeerApiException('Service Unavailable', 503));

        await provider.loadDrinks();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('Server error'));
        expect(provider.error, contains('try again later'));
        expect(provider.error, isNot(contains('BeerApiException')));
        expect(provider.error, isNot(contains('503')));
      });

      test('shows user-friendly message for network timeout', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        // Mock TimeoutException
        when(mockDrinkRepository.getDrinks(any))
            .thenThrow(TimeoutException('Connection timeout'));

        await provider.loadDrinks();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('timed out'));
        expect(provider.error, contains('check your connection'));
        expect(provider.error, isNot(contains('TimeoutException')));
      });

      test('shows user-friendly message for no internet connection', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        // http.ClientException is thrown on network failures across all platforms
        when(mockDrinkRepository.getDrinks(any))
            .thenThrow(http.ClientException('Failed host lookup'));

        await provider.loadDrinks();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('No internet connection'));
        expect(provider.error, contains('check your network'));
        expect(provider.error, isNot(contains('ClientException')));
        expect(provider.error, isNot(contains('Failed host lookup')));
      });

      test('shows generic friendly message for unknown errors', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        // Mock generic exception
        when(mockDrinkRepository.getDrinks(any))
            .thenThrow(Exception('Some random error'));

        await provider.loadDrinks();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('Something went wrong'));
        expect(provider.error, contains('try again'));
        expect(provider.error, isNot(contains('Exception')));
        expect(provider.error, isNot(contains('Some random error')));
      });

      test('shows user-friendly message for 400-level errors', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        // Mock 403 BeerApiException
        when(mockDrinkRepository.getDrinks(any))
            .thenThrow(BeerApiException('Forbidden', 403));

        await provider.loadDrinks();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('Could not load drinks'));
        expect(provider.error, contains('try again'));
        expect(provider.error, isNot(contains('BeerApiException')));
        expect(provider.error, isNot(contains('403')));
      });

      test('shows connection message for BeerApiException without status code',
          () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        // Mock BeerApiException without status code
        when(mockDrinkRepository.getDrinks(any))
            .thenThrow(BeerApiException('Network error'));

        await provider.loadDrinks();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('Could not load drinks'));
        expect(provider.error, contains('check your connection'));
        expect(provider.error, isNot(contains('BeerApiException')));
      });
    });

    group('loadFestivals error messages', () {
      test('shows user-friendly message for festival 404 error', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );

        // Mock 404 FestivalServiceException
        when(mockFestivalRepository.getFestivals())
            .thenThrow(FestivalServiceException('Not found', 404));

        await provider.loadFestivals();

        expect(provider.festivalsError, isNotNull);
        expect(provider.festivalsError, contains('Festival list not found'));
        expect(
            provider.festivalsError, isNot(contains('FestivalServiceException')));
        expect(provider.festivalsError, isNot(contains('404')));
      });

      test('shows user-friendly message for festival 500 error', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );

        // Mock 500 FestivalServiceException
        when(mockFestivalRepository.getFestivals())
            .thenThrow(FestivalServiceException('Server error', 500));

        await provider.loadFestivals();

        expect(provider.festivalsError, isNotNull);
        expect(provider.festivalsError, contains('Server error'));
        expect(provider.festivalsError, contains('try again later'));
        expect(provider.festivalsError, isNot(contains('500')));
      });

      test('shows user-friendly message for festival 502 error', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );

        // Mock 502 FestivalServiceException (Bad Gateway)
        when(mockFestivalRepository.getFestivals())
            .thenThrow(FestivalServiceException('Bad Gateway', 502));

        await provider.loadFestivals();

        expect(provider.festivalsError, isNotNull);
        expect(provider.festivalsError, contains('Server error'));
        expect(provider.festivalsError, contains('try again later'));
        expect(provider.festivalsError, isNot(contains('502')));
      });

      test('shows user-friendly message for festival 503 error', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );

        // Mock 503 FestivalServiceException (Service Unavailable)
        when(mockFestivalRepository.getFestivals())
            .thenThrow(FestivalServiceException('Service Unavailable', 503));

        await provider.loadFestivals();

        expect(provider.festivalsError, isNotNull);
        expect(provider.festivalsError, contains('Server error'));
        expect(provider.festivalsError, contains('try again later'));
        expect(provider.festivalsError, isNot(contains('503')));
      });

      test('shows user-friendly message for festival network errors', () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );

        // http.ClientException is thrown on network failures across all platforms
        when(mockFestivalRepository.getFestivals())
            .thenThrow(http.ClientException('Network unreachable'));

        await provider.loadFestivals();

        expect(provider.festivalsError, isNotNull);
        expect(provider.festivalsError, contains('No internet connection'));
        expect(provider.festivalsError, isNot(contains('ClientException')));
      });

      test('shows connection message for FestivalServiceException without status',
          () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );

        // Mock FestivalServiceException without status code
        when(mockFestivalRepository.getFestivals())
            .thenThrow(FestivalServiceException('Parse error'));

        await provider.loadFestivals();

        expect(provider.festivalsError, isNotNull);
        expect(provider.festivalsError, contains('Could not load festivals'));
        expect(provider.festivalsError, contains('check your connection'));
      });
    });

    group('setFestival error messages', () {
      test('shows user-friendly message when switching festivals fails',
          () async {
        final provider = BeerProvider(
          drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
        );
        await provider.initialize();

        const testFestival = Festival(
          id: 'test',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
        );

        // Mock 500 error when loading new festival
        when(mockDrinkRepository.getDrinks(any))
            .thenThrow(BeerApiException('Server error', 500));

        await provider.setFestival(testFestival);

        expect(provider.error, isNotNull);
        expect(provider.error, contains('Server error'));
        expect(provider.error, isNot(contains('BeerApiException')));
      });
    });
  });

  group('Analytics Event Logging', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;

    setUp(() {
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();
      SharedPreferences.setMockInitialValues({});
    });

    test('logs festival selected event when festival changes', () async {
      final provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();

      const testFestival = Festival(
        id: 'test-festival',
        name: 'Test Festival 2025',
        dataBaseUrl: 'https://example.com',
      );

      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);

      await provider.setFestival(testFestival);

      verify(mockAnalyticsService.logFestivalSelected(testFestival)).called(1);
    });

    test('logs category filter event when category changes', () async {
      final provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();

      provider.setCategory('beer');

      verify(mockAnalyticsService.logCategoryFilter('beer')).called(1);
    });

    test('logs style filter event when style toggles', () async {
      final provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();

      provider.toggleStyle('IPA');

      verify(mockAnalyticsService.logStyleFilter({'IPA'})).called(1);
    });

    test('logs sort change event when sort type changes', () async {
      final provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();

      provider.setSort(DrinkSort.abvHigh);

      verify(mockAnalyticsService.logSortChange('abvHigh')).called(1);
    });

    test('logs search event when search query is not empty', () async {
      final provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();

      provider.setSearchQuery('test beer');

      verify(mockAnalyticsService.logSearch('test beer')).called(1);
    });

    test('does not log search event when search query is empty', () async {
      final provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();

      provider.setSearchQuery('');

      verifyNever(mockAnalyticsService.logSearch(any));
    });

    test('logs favorite added event when drink is favorited', () async {
      final provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();

      const testProducer = Producer(
        id: 'producer-1',
        name: 'Test Brewery',
        location: 'Test City',
        products: [],
      );

      const testProduct = Product(
        id: 'test-1',
        name: 'Test Beer',
        abv: 5.0,
        category: 'beer',
        dispense: 'Cask',
      );

      final testDrink = Drink(
        product: testProduct,
        producer: testProducer,
        festivalId: 'test-festival',
      );

      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [testDrink]);
      await provider.loadDrinks();

      // Mock toggleFavorite to properly toggle state
      final favorites = <String>{};
      when(mockDrinkRepository.toggleFavorite(any, any)).thenAnswer((invocation) async {
        final drinkId = invocation.positionalArguments[1] as String;
        if (favorites.contains(drinkId)) {
          favorites.remove(drinkId);
          return false;
        } else {
          favorites.add(drinkId);
          return true;
        }
      });

      await provider.toggleFavorite(testDrink);

      verify(mockAnalyticsService.logFavoriteAdded(testDrink)).called(1);
    });

    test('logs favorite removed event when drink is unfavorited', () async {
      final provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();

      const testProducer = Producer(
        id: 'producer-1',
        name: 'Test Brewery',
        location: 'Test City',
        products: [],
      );

      const testProduct = Product(
        id: 'test-1',
        name: 'Test Beer',
        abv: 5.0,
        category: 'beer',
        dispense: 'Cask',
      );

      final testDrink = Drink(
        product: testProduct,
        producer: testProducer,
        festivalId: 'test-festival',
      );

      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [testDrink]);
      await provider.loadDrinks();

      // Mock toggleFavorite to properly toggle state
      final favorites = <String>{};
      when(mockDrinkRepository.toggleFavorite(any, any)).thenAnswer((invocation) async {
        final drinkId = invocation.positionalArguments[1] as String;
        if (favorites.contains(drinkId)) {
          favorites.remove(drinkId);
          return false;
        } else {
          favorites.add(drinkId);
          return true;
        }
      });

      // Favorite then unfavorite
      await provider.toggleFavorite(testDrink);
      await provider.toggleFavorite(testDrink);

      verify(mockAnalyticsService.logFavoriteRemoved(testDrink)).called(1);
    });

    test('logs rating given event when drink is rated', () async {
      final provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();

      const testProducer = Producer(
        id: 'producer-1',
        name: 'Test Brewery',
        location: 'Test City',
        products: [],
      );

      const testProduct = Product(
        id: 'test-1',
        name: 'Test Beer',
        abv: 5.0,
        category: 'beer',
        dispense: 'Cask',
      );

      final testDrink = Drink(
        product: testProduct,
        producer: testProducer,
        festivalId: 'test-festival',
      );

      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [testDrink]);
      await provider.loadDrinks();

      await provider.setRating(testDrink, 5);

      verify(mockAnalyticsService.logRatingGiven(testDrink, 5)).called(1);
    });

    test('does not log rating event when rating is cleared', () async {
      final provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();

      const testProducer = Producer(
        id: 'producer-1',
        name: 'Test Brewery',
        location: 'Test City',
        products: [],
      );

      const testProduct = Product(
        id: 'test-1',
        name: 'Test Beer',
        abv: 5.0,
        category: 'beer',
        dispense: 'Cask',
      );

      final testDrink = Drink(
        product: testProduct,
        producer: testProducer,
        festivalId: 'test-festival',
      );

      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [testDrink]);
      await provider.loadDrinks();

      await provider.setRating(testDrink, null);

      verifyNever(mockAnalyticsService.logRatingGiven(any, any));
    });
  });
}
