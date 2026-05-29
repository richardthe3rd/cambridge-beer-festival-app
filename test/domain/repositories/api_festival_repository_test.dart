import 'package:cambridge_beer_festival/domain/repositories/repositories.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_festival_repository_test.mocks.dart';

@GenerateNiceMocks([MockSpec<FestivalService>(), MockSpec<AnalyticsService>()])
void main() {
  group('ApiFestivalRepository', () {
    late MockFestivalService festivalService;
    late FestivalStorageService storageService;
    late FestivalCacheService cacheService;
    late MockAnalyticsService analyticsService;
    late ApiFestivalRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      festivalService = MockFestivalService();
      storageService = FestivalStorageService(prefs);
      cacheService = FestivalCacheService(prefs);
      analyticsService = MockAnalyticsService();
      repository = ApiFestivalRepository(
        festivalService: festivalService,
        festivalStorageService: storageService,
        cacheService: cacheService,
        analyticsService: analyticsService,
      );
    });

    test('getFestivals delegates to the festival service', () async {
      final response = FestivalsResponse.fromJson({
        'festivals': [
          {
            'id': 'cbf2025',
            'name': 'Cambridge Beer Festival 2025',
            'data_base_url': 'https://example.com/cbf2025',
          },
        ],
        'default_festival_id': 'cbf2025',
      }, 'https://example.com');
      when(festivalService.fetchFestivals()).thenAnswer((_) async => response);

      final result = await repository.getFestivals();

      expect(result, same(response));
      verify(festivalService.fetchFestivals()).called(1);
    });

    test('getFestivals propagates festival service failures', () async {
      when(
        festivalService.fetchFestivals(),
      ).thenThrow(FestivalServiceException('boom', 500));

      expect(
        () => repository.getFestivals(),
        throwsA(isA<FestivalServiceException>()),
      );
    });

    test('getFestivals caches the fetched response', () async {
      final response = FestivalsResponse.fromJson({
        'festivals': [
          {
            'id': 'cbf2025',
            'name': 'Cambridge Beer Festival 2025',
            'data_base_url': 'https://example.com/cbf2025',
          },
        ],
        'default_festival_id': 'cbf2025',
      }, 'https://example.com');
      when(festivalService.fetchFestivals()).thenAnswer((_) async => response);

      await repository.getFestivals();
      await pumpEventQueue(); // cache write is intentionally backgrounded

      final cached = await repository.getCachedFestivals();
      expect(cached, isNotNull);
      expect(cached!.festivals.single.id, 'cbf2025');
      expect(cached.defaultFestivalId, 'cbf2025');
    });

    test('getCachedFestivals returns null when nothing is cached', () async {
      expect(await repository.getCachedFestivals(), isNull);
    });

    test('getSelectedFestivalId returns null before any selection', () async {
      expect(await repository.getSelectedFestivalId(), isNull);
    });

    test(
      'setSelectedFestivalId then getSelectedFestivalId round-trips',
      () async {
        await repository.setSelectedFestivalId('cbf2025');

        expect(await repository.getSelectedFestivalId(), 'cbf2025');
        expect(storageService.getSelectedFestivalId(), 'cbf2025');
      },
    );

    test('setSelectedFestivalId overwrites a previous selection', () async {
      await repository.setSelectedFestivalId('cbf2024');
      await repository.setSelectedFestivalId('cbf2025');

      expect(await repository.getSelectedFestivalId(), 'cbf2025');
    });

    test('dispose closes the festival service', () {
      repository.dispose();
      verify(festivalService.dispose()).called(1);
    });
  });
}
