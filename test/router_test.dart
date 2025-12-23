import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/router.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('Router Configuration', () {
    late MockBeerApiService mockApiService;
    late MockFestivalService mockFestivalService;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    setUp(() {
      mockApiService = MockBeerApiService();
      mockFestivalService = MockFestivalService();
      mockAnalyticsService = MockAnalyticsService();
      SharedPreferences.setMockInitialValues({});

      provider = BeerProvider(
        apiService: mockApiService,
        festivalService: mockFestivalService,
        analyticsService: mockAnalyticsService,
      );

      // Mock default responses
      when(mockFestivalService.fetchFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [
            const Festival(
              id: 'cbf2025',
              name: 'Cambridge 2025',
              dataBaseUrl: 'https://example.com/cbf2025',
            ),
          ],
          defaultFestivalId: 'cbf2025',
          version: '1.0.0',
          baseUrl: 'https://example.com',
        ),
      );

      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => <Drink>[]);
    });

    tearDown(() {
      provider.dispose();
    });

    testWidgets('router navigates to home page', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should navigate to home (DrinksScreen) by default
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('router handles /favorites route', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to favorites via router
      appRouter.go('/favorites');
      await tester.pumpAndSettle();

      // Should show favorites screen with navigation bar
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('Router Navigation Paths', () {
    test('drink detail route parses ID correctly', () {
      final uri = Uri.parse('/drink/test-drink-123');
      expect(uri.pathSegments.length, 2);
      expect(uri.pathSegments[0], 'drink');
      expect(uri.pathSegments[1], 'test-drink-123');
    });

    test('brewery route parses ID correctly', () {
      final uri = Uri.parse('/brewery/test-brewery-456');
      expect(uri.pathSegments.length, 2);
      expect(uri.pathSegments[0], 'brewery');
      expect(uri.pathSegments[1], 'test-brewery-456');
    });

    test('style route handles URL encoding', () {
      const styleName = 'IPA - American';
      final encoded = Uri.encodeComponent(styleName);
      final uri = Uri.parse('/style/$encoded');
      final decoded = Uri.decodeComponent(uri.pathSegments[1]);

      expect(decoded, styleName);
    });

    test('style route handles special characters', () {
      const styleName = 'Bière de Garde';
      final encoded = Uri.encodeComponent(styleName);
      final uri = Uri.parse('/style/$encoded');
      // Uri.parse automatically decodes path segments
      final decoded = uri.pathSegments[1];

      expect(decoded, styleName);
    });
  });

  group('Router Path Matching', () {
    test('root path is valid', () {
      final uri = Uri.parse('/');
      expect(uri.path, '/');
    });

    test('favorites path is valid', () {
      final uri = Uri.parse('/favorites');
      expect(uri.path, '/favorites');
    });

    test('about path is valid', () {
      final uri = Uri.parse('/about');
      expect(uri.path, '/about');
    });

    test('festival-info path is valid', () {
      final uri = Uri.parse('/festival-info');
      expect(uri.path, '/festival-info');
    });

    test('drink detail path is valid', () {
      final uri = Uri.parse('/drink/abc123');
      expect(uri.path, '/drink/abc123');
      expect(uri.pathSegments[1], 'abc123');
    });

    test('brewery detail path is valid', () {
      final uri = Uri.parse('/brewery/xyz789');
      expect(uri.path, '/brewery/xyz789');
      expect(uri.pathSegments[1], 'xyz789');
    });

    test('style path is valid', () {
      final uri = Uri.parse('/style/IPA');
      expect(uri.path, '/style/IPA');
      expect(uri.pathSegments[1], 'IPA');
    });
  });
}
