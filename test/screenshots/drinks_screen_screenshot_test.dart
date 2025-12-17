import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_test.mocks.dart';
import '../fixtures/test_data.dart';
import '../helpers/screenshot_helper.dart';

void main() {
  group('DrinksScreen Screenshot Tests', () {
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

    testWidgets('DrinksScreen - phone size', (WidgetTester tester) async {
      // Mock API response
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => allTestDrinks);
      await provider.loadDrinks();

      // Take screenshots
      await screenshotLightAndDark(
        tester: tester,
        screenWidget: const DrinksScreen(),
        provider: provider,
        screenName: 'drinks_screen_phone',
        size: ScreenSizes.phone,
      );
    });

    testWidgets('DrinksScreen - tablet size', (WidgetTester tester) async {
      // Mock API response
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => allTestDrinks);
      await provider.loadDrinks();

      // Take screenshots
      await screenshotLightAndDark(
        tester: tester,
        screenWidget: const DrinksScreen(),
        provider: provider,
        screenName: 'drinks_screen_tablet',
        size: ScreenSizes.tablet,
      );
    });

    testWidgets('DrinksScreen - with search', (WidgetTester tester) async {
      // Mock API response
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => allTestDrinks);
      await provider.loadDrinks();

      // Set search query
      provider.setSearchQuery('IPA');

      // Take screenshots
      await screenshotLightAndDark(
        tester: tester,
        screenWidget: const DrinksScreen(),
        provider: provider,
        screenName: 'drinks_screen_search',
        size: ScreenSizes.phone,
      );
    });

    testWidgets('DrinksScreen - empty state', (WidgetTester tester) async {
      // Mock empty API response
      when(mockApiService.fetchAllDrinks(any)).thenAnswer((_) async => []);
      await provider.loadDrinks();

      // Take screenshots
      await screenshotLightAndDark(
        tester: tester,
        screenWidget: const DrinksScreen(),
        provider: provider,
        screenName: 'drinks_screen_empty',
        size: ScreenSizes.phone,
      );
    });
  });
}
