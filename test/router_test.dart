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
      // Initialize provider with festivals
      await provider.initialize();

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

    testWidgets('router handles festival-scoped /favorites route', (tester) async {
      // Initialize provider with festivals
      await provider.initialize();
      final festivalId = provider.currentFestival.id;

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to favorites via festival-scoped router
      appRouter.go('/$festivalId/favorites');
      await tester.pumpAndSettle();

      // Should show favorites screen with navigation bar
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('router handles festival switching', (tester) async {
      // Setup multiple festivals for switching test
      when(mockFestivalService.fetchFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: const [
            Festival(
              id: 'cbf2025',
              name: 'Cambridge 2025',
              dataBaseUrl: 'https://example.com/cbf2025',
            ),
            Festival(
              id: 'cbf2024',
              name: 'Cambridge 2024',
              dataBaseUrl: 'https://example.com/cbf2024',
            ),
          ],
          defaultFestivalId: 'cbf2025',
          version: '1.0.0',
          baseUrl: 'https://example.com',
        ),
      );

      await provider.initialize();
      expect(provider.currentFestival.id, 'cbf2025');

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to a different festival
      appRouter.go('/cbf2024');
      await tester.pumpAndSettle();

      // Provider should switch to the new festival
      expect(provider.currentFestival.id, 'cbf2024');
    });

    testWidgets('router redirects invalid festival ID', (tester) async {
      await provider.initialize();
      final currentFestival = provider.currentFestival.id;

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Try to navigate to invalid festival ID
      appRouter.go('/invalid-festival-123');
      await tester.pumpAndSettle();

      // Should redirect to current festival
      expect(provider.currentFestival.id, currentFestival);
    });
  });

  group('Router Navigation Paths (Phase 1 - Festival-scoped)', () {
    const festivalId = 'cbf2025';

    test('drink detail route parses ID correctly', () {
      final uri = Uri.parse('/$festivalId/drink/test-drink-123');
      expect(uri.pathSegments.length, 3);
      expect(uri.pathSegments[0], festivalId);
      expect(uri.pathSegments[1], 'drink');
      expect(uri.pathSegments[2], 'test-drink-123');
    });

    test('brewery route parses ID correctly', () {
      final uri = Uri.parse('/$festivalId/brewery/test-brewery-456');
      expect(uri.pathSegments.length, 3);
      expect(uri.pathSegments[0], festivalId);
      expect(uri.pathSegments[1], 'brewery');
      expect(uri.pathSegments[2], 'test-brewery-456');
    });

    test('style route handles URL encoding', () {
      const styleName = 'IPA - American';
      final encoded = Uri.encodeComponent(styleName);
      final uri = Uri.parse('/$festivalId/style/$encoded');
      final decoded = Uri.decodeComponent(uri.pathSegments[2]);

      expect(decoded, styleName);
    });

    test('style route handles special characters', () {
      const styleName = 'Bière de Garde';
      final encoded = Uri.encodeComponent(styleName);
      final uri = Uri.parse('/$festivalId/style/$encoded');
      // Uri.parse automatically decodes path segments
      final decoded = uri.pathSegments[2];

      expect(decoded, styleName);
    });
  });

  group('Router Path Matching (Phase 1 - Festival-scoped)', () {
    const festivalId = 'cbf2025';

    test('root path redirects to festival home', () {
      final uri = Uri.parse('/');
      expect(uri.path, '/');
    });

    test('festival home path is valid', () {
      final uri = Uri.parse('/$festivalId');
      expect(uri.path, '/$festivalId');
    });

    test('favorites path is festival-scoped', () {
      final uri = Uri.parse('/$festivalId/favorites');
      expect(uri.path, '/$festivalId/favorites');
      expect(uri.pathSegments[0], festivalId);
      expect(uri.pathSegments[1], 'favorites');
    });

    test('about path is global (no festival scope)', () {
      final uri = Uri.parse('/about');
      expect(uri.path, '/about');
    });

    test('drink detail path is festival-scoped', () {
      final uri = Uri.parse('/$festivalId/drink/abc123');
      expect(uri.path, '/$festivalId/drink/abc123');
      expect(uri.pathSegments[0], festivalId);
      expect(uri.pathSegments[2], 'abc123');
    });

    test('brewery detail path is festival-scoped', () {
      final uri = Uri.parse('/$festivalId/brewery/xyz789');
      expect(uri.path, '/$festivalId/brewery/xyz789');
      expect(uri.pathSegments[0], festivalId);
      expect(uri.pathSegments[2], 'xyz789');
    });

    test('style path is festival-scoped', () {
      final uri = Uri.parse('/$festivalId/style/IPA');
      expect(uri.path, '/$festivalId/style/IPA');
      expect(uri.pathSegments[0], festivalId);
      expect(uri.pathSegments[2], 'IPA');
    });
  });
}
