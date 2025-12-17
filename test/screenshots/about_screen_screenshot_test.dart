import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../provider_test.mocks.dart';
import '../fixtures/test_data.dart';
import '../helpers/screenshot_helper.dart';

void main() {
  group('AboutScreen Screenshot Tests', () {
    late MockBeerApiService mockApiService;
    late MockFestivalService mockFestivalService;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Cambridge Beer Festival',
        packageName: 'ralcock.cbf',
        version: '2025.12.0',
        buildNumber: '20251200',
        buildSignature: '',
      );
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

    testWidgets('AboutScreen - phone size', (WidgetTester tester) async {
      // Mock API response
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => allTestDrinks);
      await provider.loadDrinks();

      // Take screenshots
      await screenshotLightAndDark(
        tester: tester,
        screenWidget: const AboutScreen(),
        provider: provider,
        screenName: 'about_screen_phone',
        size: ScreenSizes.phone,
      );
    });

    testWidgets('AboutScreen - tablet size', (WidgetTester tester) async {
      // Mock API response
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => allTestDrinks);
      await provider.loadDrinks();

      // Take screenshots
      await screenshotLightAndDark(
        tester: tester,
        screenWidget: const AboutScreen(),
        provider: provider,
        screenName: 'about_screen_tablet',
        size: ScreenSizes.tablet,
      );
    });
  });
}
