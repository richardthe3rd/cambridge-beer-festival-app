import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_test.mocks.dart';
import '../fixtures/test_data.dart';
import '../helpers/screenshot_helper.dart';

void main() {
  group('FestivalInfoScreen Screenshot Tests', () {
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

    testWidgets('FestivalInfoScreen - phone size', (WidgetTester tester) async {
      // Mock API response
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => allTestDrinks);
      await provider.loadDrinks();

      // Take screenshots
      await screenshotLightAndDark(
        tester: tester,
        screenWidget: const FestivalInfoScreen(),
        provider: provider,
        screenName: 'festival_info_screen_phone',
        size: ScreenSizes.phone,
      );
    });

    testWidgets('FestivalInfoScreen - tablet size', (WidgetTester tester) async {
      // Mock API response
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => allTestDrinks);
      await provider.loadDrinks();

      // Take screenshots
      await screenshotLightAndDark(
        tester: tester,
        screenWidget: const FestivalInfoScreen(),
        provider: provider,
        screenName: 'festival_info_screen_tablet',
        size: ScreenSizes.tablet,
      );
    });
  });
}
