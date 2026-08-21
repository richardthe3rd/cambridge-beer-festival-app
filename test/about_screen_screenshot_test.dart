import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('AboutScreen Screenshot Tests', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // Fixed values so the golden is deterministic — a moving version
      // string (e.g. sourced from pubspec.yaml at build time) would make
      // this golden flap between runs.
      PackageInfo.setMockInitialValues(
        appName: 'Cambridge Beer Festival',
        packageName: 'ralcock.cbf',
        version: '2025.12.0',
        buildNumber: '20251200',
        buildSignature: '',
      );

      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();
      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    // AboutScreen needs no drink/festival repository stubbing and no
    // provider.initialize() — it only reads provider.themeMode and
    // PackageInfo. Its `context.go('/')` home button only fires inside
    // onPressed (never during build), and canPopNavigation() catches the
    // absence of a GoRouter and returns false, so a plain MaterialApp
    // renders correctly with no GoRouter wrapper needed.
    Widget buildApp(Brightness brightness) {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(
          // Use the real app theme so these goldens cover `appBarTheme` and
          // the text theme, not just the colour scheme (#520).
          theme: buildAppTheme(brightness),
          home: const AboutScreen(),
        ),
      );
    }

    testWidgets('AboutScreen - light theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildApp(Brightness.light));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AboutScreen),
        matchesGoldenFile('goldens/about_screen_light.png'),
      );
    });

    testWidgets('AboutScreen - dark theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildApp(Brightness.dark));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AboutScreen),
        matchesGoldenFile('goldens/about_screen_dark.png'),
      );
    });
  });
}
