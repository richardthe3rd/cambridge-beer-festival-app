import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_test.mocks.dart';
import '../fixtures/test_data.dart';
import '../helpers/screenshot_helper.dart';

void main() {
  group('BreweryScreen Screenshot Tests', () {
    late MockBeerApiService mockApiService;
    late MockFestivalService mockFestivalService;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockApiService = MockBeerApiService();
      mockFestivalService = MockFestivalService();
      mockAnalyticsService = MockAnalyticsService();
      provider = BeerProvider(
        apiService: mockApiService,
        festivalService: mockFestivalService,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
    });

    tearDown(() {
      provider.dispose();
    });

    testWidgets('BreweryScreen - tablet size', (WidgetTester tester) async {
      // Mock API response
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => allTestDrinks);
      await provider.loadDrinks();

      // Take screenshots - tablet size to avoid layout overflow
      await screenshotLightAndDark(
        tester: tester,
        screenWidget: const BreweryScreen(breweryId: 'brewery1'),
        provider: provider,
        screenName: 'brewery_screen',
        size: ScreenSizes.tablet,
      );
    });
  });
}
