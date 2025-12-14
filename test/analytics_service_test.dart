import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/services/analytics_service.dart';
import 'package:cambridge_beer_festival/models/models.dart';

void main() {
  group('AnalyticsService', () {
    late AnalyticsService service;

    setUp(() {
      service = AnalyticsService();
    });

    test('analytics methods complete without errors', () async {
      // These should not throw even if Firebase is not initialized in tests
      await service.logAppLaunch();
      await service.logSearch('test query');
      await service.logCategoryFilter('beer');
      await service.logStyleFilter({'IPA', 'Stout'});
      await service.logSortChange('nameAsc');
      
      const festival = Festival(
        id: 'test',
        name: 'Test Festival',
        dataBaseUrl: 'https://example.com',
      );
      await service.logFestivalSelected(festival);

      const producer = Producer(
        id: '1',
        name: 'Test Brewery',
        location: 'Test Location',
        products: [],
      );

      const product = Product(
        id: '1',
        name: 'Test Beer',
        category: 'beer',
        dispense: 'cask',
        abv: 5.0,
      );

      final drink = Drink(
        festivalId: 'test',
        producer: producer,
        product: product,
      );
      
      await service.logFavoriteAdded(drink);
      await service.logFavoriteRemoved(drink);
      await service.logDrinkViewed(drink);
      await service.logBreweryViewed('Test Brewery');
      await service.logStyleViewed('IPA');
      await service.logRatingGiven(drink, 5);
      await service.logDrinkShared(drink);
      await service.setUserProperty('theme', 'dark');
      await service.setUserId('test-user');
      
      // Test completes successfully
      expect(true, isTrue);
    });

    test('logError completes without errors', () async {
      await service.logError(
        Exception('Test error'),
        StackTrace.current,
        reason: 'Test reason',
      );
      
      expect(true, isTrue);
    });
  });
}
