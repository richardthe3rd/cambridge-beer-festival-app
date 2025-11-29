import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

@GenerateMocks([BeerApiService, FestivalService])
void main() {
  group('BeerProvider Error Message Handling', () {
    late MockBeerApiService mockApiService;
    late MockFestivalService mockFestivalService;

    setUp(() {
      mockApiService = MockBeerApiService();
      mockFestivalService = MockFestivalService();
      SharedPreferences.setMockInitialValues({});
    });

    group('loadDrinks error messages', () {
      test('shows user-friendly message for 404 error', () async {
        final provider = BeerProvider(
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );
        await provider.initialize();

        // Mock 404 BeerApiException
        when(mockApiService.fetchAllDrinks(any))
            .thenThrow(BeerApiException('Not found', 404));

        await provider.loadDrinks();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('Festival data not found'));
        expect(provider.error, isNot(contains('BeerApiException')));
        expect(provider.error, isNot(contains('404')));
      });

      test('shows user-friendly message for 500 error', () async {
        final provider = BeerProvider(
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );
        await provider.initialize();

        // Mock 500 BeerApiException
        when(mockApiService.fetchAllDrinks(any))
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
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );
        await provider.initialize();

        // Mock 502 BeerApiException (Bad Gateway)
        when(mockApiService.fetchAllDrinks(any))
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
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );
        await provider.initialize();

        // Mock 503 BeerApiException (Service Unavailable)
        when(mockApiService.fetchAllDrinks(any))
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
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );
        await provider.initialize();

        // Mock TimeoutException
        when(mockApiService.fetchAllDrinks(any))
            .thenThrow(TimeoutException('Connection timeout'));

        await provider.loadDrinks();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('timed out'));
        expect(provider.error, contains('check your connection'));
        expect(provider.error, isNot(contains('TimeoutException')));
      });

      test('shows user-friendly message for no internet connection', () async {
        final provider = BeerProvider(
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );
        await provider.initialize();

        // Mock SocketException (no internet)
        when(mockApiService.fetchAllDrinks(any))
            .thenThrow(const SocketException('Failed host lookup'));

        await provider.loadDrinks();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('No internet connection'));
        expect(provider.error, contains('check your network'));
        expect(provider.error, isNot(contains('SocketException')));
        expect(provider.error, isNot(contains('Failed host lookup')));
      });

      test('shows generic friendly message for unknown errors', () async {
        final provider = BeerProvider(
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );
        await provider.initialize();

        // Mock generic exception
        when(mockApiService.fetchAllDrinks(any))
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
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );
        await provider.initialize();

        // Mock 403 BeerApiException
        when(mockApiService.fetchAllDrinks(any))
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
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );
        await provider.initialize();

        // Mock BeerApiException without status code
        when(mockApiService.fetchAllDrinks(any))
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
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );

        // Mock 404 FestivalServiceException
        when(mockFestivalService.fetchFestivals())
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
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );

        // Mock 500 FestivalServiceException
        when(mockFestivalService.fetchFestivals())
            .thenThrow(FestivalServiceException('Server error', 500));

        await provider.loadFestivals();

        expect(provider.festivalsError, isNotNull);
        expect(provider.festivalsError, contains('Server error'));
        expect(provider.festivalsError, contains('try again later'));
        expect(provider.festivalsError, isNot(contains('500')));
      });

      test('shows user-friendly message for festival 502 error', () async {
        final provider = BeerProvider(
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );

        // Mock 502 FestivalServiceException (Bad Gateway)
        when(mockFestivalService.fetchFestivals())
            .thenThrow(FestivalServiceException('Bad Gateway', 502));

        await provider.loadFestivals();

        expect(provider.festivalsError, isNotNull);
        expect(provider.festivalsError, contains('Server error'));
        expect(provider.festivalsError, contains('try again later'));
        expect(provider.festivalsError, isNot(contains('502')));
      });

      test('shows user-friendly message for festival 503 error', () async {
        final provider = BeerProvider(
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );

        // Mock 503 FestivalServiceException (Service Unavailable)
        when(mockFestivalService.fetchFestivals())
            .thenThrow(FestivalServiceException('Service Unavailable', 503));

        await provider.loadFestivals();

        expect(provider.festivalsError, isNotNull);
        expect(provider.festivalsError, contains('Server error'));
        expect(provider.festivalsError, contains('try again later'));
        expect(provider.festivalsError, isNot(contains('503')));
      });

      test('shows user-friendly message for festival network errors', () async {
        final provider = BeerProvider(
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );

        // Mock SocketException
        when(mockFestivalService.fetchFestivals())
            .thenThrow(const SocketException('Network unreachable'));

        await provider.loadFestivals();

        expect(provider.festivalsError, isNotNull);
        expect(provider.festivalsError, contains('No internet connection'));
        expect(provider.festivalsError, isNot(contains('SocketException')));
      });

      test('shows connection message for FestivalServiceException without status',
          () async {
        final provider = BeerProvider(
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );

        // Mock FestivalServiceException without status code
        when(mockFestivalService.fetchFestivals())
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
          apiService: mockApiService,
          festivalService: mockFestivalService,
        );
        await provider.initialize();

        final testFestival = Festival(
          id: 'test',
          name: 'Test Festival',
          dataBaseUrl: 'https://example.com',
        );

        // Mock 500 error when loading new festival
        when(mockApiService.fetchAllDrinks(any))
            .thenThrow(BeerApiException('Server error', 500));

        await provider.setFestival(testFestival);

        expect(provider.error, isNotNull);
        expect(provider.error, contains('Server error'));
        expect(provider.error, isNot(contains('BeerApiException')));
      });
    });
  });
}
