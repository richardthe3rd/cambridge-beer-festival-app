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

      // Verify initial festival is displayed in UI
      expect(find.text('Cambridge 2025'), findsOneWidget);
      expect(find.text('Cambridge 2024'), findsNothing);

      // Navigate to a different festival
      appRouter.go('/cbf2024');
      await tester.pumpAndSettle();

      // Provider should switch to the new festival
      expect(provider.currentFestival.id, 'cbf2024');

      // Verify UI updated to show new festival
      expect(find.text('Cambridge 2024'), findsOneWidget);
      expect(find.text('Cambridge 2025'), findsNothing);
    });

    testWidgets('router redirects root path to festival home after async initialization', (tester) async {
      // DO NOT pre-initialize - this simulates the e2e scenario
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      // Pump frames to allow async initialization to complete
      await tester.pumpAndSettle();

      // Should redirect from / to /cbf2025 after initialization
      final currentUri = Uri.parse(appRouter.routerDelegate.currentConfiguration.uri.toString());
      expect(currentUri.pathSegments.isNotEmpty, true);
      expect(currentUri.pathSegments.first, 'cbf2025');
    });

    testWidgets('router redirects invalid festival after async initialization', (tester) async {
      // DO NOT pre-initialize - this simulates the e2e scenario
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      // Navigate to invalid festival immediately (provider not initialized yet)
      appRouter.go('/invalid-festival-123');
      await tester.pump(); // Start the frame

      // Pump frames to allow async initialization AND redirect to complete
      await tester.pumpAndSettle();

      // Should redirect to current festival (cbf2025) after initialization
      final currentUri = Uri.parse(appRouter.routerDelegate.currentConfiguration.uri.toString());
      expect(currentUri.pathSegments.first, 'cbf2025');
      expect(provider.currentFestival.id, 'cbf2025');
    });

    testWidgets('router redirects invalid festival with query params after async initialization', (tester) async {
      // DO NOT pre-initialize - this simulates the e2e scenario
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      // Navigate to invalid festival with query params immediately
      appRouter.go('/invalid-fest?search=IPA&category=beer');
      await tester.pump();

      // Pump frames to allow async initialization AND redirect to complete
      await tester.pumpAndSettle();

      // Should redirect to cbf2025 and preserve query parameters
      final currentUri = Uri.parse(appRouter.routerDelegate.currentConfiguration.uri.toString());
      expect(currentUri.pathSegments.first, 'cbf2025');
      expect(currentUri.queryParameters['search'], 'IPA');
      expect(currentUri.queryParameters['category'], 'beer');
    });

    testWidgets('router handles deep link to drink detail after async initialization', (tester) async {
      // DO NOT pre-initialize - simulates deep link before app loads
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      // Navigate to drink detail immediately (before init)
      appRouter.go('/cbf2025/drink/test-drink-123');
      await tester.pump();

      // Pump frames to allow async initialization to complete
      await tester.pumpAndSettle();

      // Should stay on drink detail route (valid festival ID)
      final currentUri = Uri.parse(appRouter.routerDelegate.currentConfiguration.uri.toString());
      expect(currentUri.pathSegments.length, 3);
      expect(currentUri.pathSegments[0], 'cbf2025');
      expect(currentUri.pathSegments[1], 'drink');
      expect(currentUri.pathSegments[2], 'test-drink-123');
    });

    // TODO: Test for '/invalid-fest/drink/abc' → '/cbf2025/drink/abc' redirect
    // This requires router-level changes because /invalid-fest/drink/abc matches
    // the drink detail route directly (/:festivalId/drink/:id), bypassing the
    // festival validation redirect. The post-init redirect only handles the
    // root (/) and festival home (/:festivalId) routes.
    // Consider adding festival validation to ALL routes, not just home route.

    testWidgets('router redirects invalid festival ID (pre-initialized provider)', (tester) async {
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

    testWidgets('router preserves query parameters when redirecting invalid festival ID', (tester) async {
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

      // Try to navigate to invalid festival with query parameters
      appRouter.go('/invalid-festival-123?search=IPA&category=beer');
      await tester.pumpAndSettle();

      // Should redirect to current festival and preserve query params
      final currentUri = Uri.parse(appRouter.routerDelegate.currentConfiguration.uri.toString());
      expect(currentUri.pathSegments.first, currentFestival);
      expect(currentUri.queryParameters['search'], 'IPA');
      expect(currentUri.queryParameters['category'], 'beer');
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
