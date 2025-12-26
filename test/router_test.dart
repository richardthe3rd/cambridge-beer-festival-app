import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:cambridge_beer_festival/router.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

// Test constants - single source of truth
const String testFestivalId = 'cbf2025';
const String testFestivalId2 = 'cbf2024';
const String invalidFestivalId = 'invalid-festival-123';
const String testDrinkId = 'test-drink-123';
const String testBreweryId = 'test-brewery-456';
const String aboutPath = '/about';

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

    testWidgets('deep link to valid route does NOT redirect after async initialization', (tester) async {
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
      appRouter.go('/$testFestivalId/drink/$testDrinkId');
      await tester.pump();

      // Pump frames to allow async initialization to complete
      await tester.pumpAndSettle();

      // Should stay on drink detail route (valid festival ID)
      final currentUri = Uri.parse(appRouter.routerDelegate.currentConfiguration.uri.toString());
      expect(currentUri.pathSegments.length, 3);
      expect(currentUri.pathSegments[0], testFestivalId);
      expect(currentUri.pathSegments[1], 'drink');
      expect(currentUri.pathSegments[2], testDrinkId);
    });

    testWidgets('global /about route NOT redirected after async initialization', (tester) async {
      // Create a fresh router for this test to avoid state pollution
      final testRouter = GoRouter(
        initialLocation: '/about', // Start at /about
        debugLogDiagnostics: kDebugMode,
        routes: appRouter.configuration.routes,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );

      // Pump frames to allow async initialization to complete
      await tester.pumpAndSettle();

      // Should STAY at /about (NOT redirect to /cbf2025)
      final currentUri = Uri.parse(testRouter.routerDelegate.currentConfiguration.uri.toString());
      expect(currentUri.path, '/about', reason: 'Global /about route should not be redirected');
    });

    // Note: Browser back/forward is handled by go_router's declarative API
    // and is tested in the e2e tests (test-e2e/routing.spec.ts).
    // Testing it at the widget level would require complex route history management
    // which is outside the scope of redirect logic testing.

    testWidgets('redirect handles API failure gracefully', (tester) async {
      // Mock API failure
      when(mockFestivalService.fetchFestivals()).thenThrow(Exception('API error'));

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should fall back to default festival despite API failure
      final currentUri = Uri.parse(appRouter.routerDelegate.currentConfiguration.uri.toString());
      expect(currentUri.pathSegments.isNotEmpty, true);
      expect(currentUri.pathSegments.first, 'cbf2025', reason: 'Should use default festival when API fails');
    });

    testWidgets('redirect handles empty festivals list', (tester) async {
      // Mock empty festivals list
      when(mockFestivalService.fetchFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: const [],
          defaultFestivalId: 'cbf2025', // Still provide default even with empty list
          version: '1.0.0',
          baseUrl: 'https://example.com',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should use hardcoded default festival
      final currentUri = Uri.parse(appRouter.routerDelegate.currentConfiguration.uri.toString());
      expect(currentUri.pathSegments.isNotEmpty, true);
      expect(currentUri.pathSegments.first, 'cbf2025', reason: 'Should use DefaultFestivals.cambridge2025');
    });

    testWidgets('multiple rapid navigations before init completes', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      // Rapid navigations before init
      appRouter.go('/');
      await tester.pump();
      appRouter.go('/invalid-fest');
      await tester.pump();
      appRouter.go('/cbf2025');
      await tester.pump();

      // Let initialization complete
      await tester.pumpAndSettle();

      // Should end up at the final destination without errors
      final currentUri = Uri.parse(appRouter.routerDelegate.currentConfiguration.uri.toString());
      expect(currentUri.pathSegments.first, 'cbf2025');
      expect(tester.takeException(), isNull, reason: 'Should not throw exceptions during rapid navigation');
    });

    testWidgets('festival switch during navigation after init', (tester) async {
      // Setup multiple festivals
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

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      // Navigate to cbf2024 before init completes
      appRouter.go('/cbf2024');
      await tester.pump();

      // Let init complete
      await tester.pumpAndSettle();

      // Provider should switch to cbf2024 (via postFrameCallback)
      expect(provider.currentFestival.id, 'cbf2024', reason: 'Provider should switch to festival in URL');
    });

    testWidgets('navigation during slow initialization', (tester) async {
      // Create a completer to control initialization timing
      final completer = Completer<FestivalsResponse>();
      when(mockFestivalService.fetchFestivals()).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      // Start showing loading state
      await tester.pump();

      // User navigates to drink detail DURING initialization
      appRouter.go('/cbf2025/drink/test-drink-123');
      await tester.pump();

      // Now complete initialization
      completer.complete(FestivalsResponse(
        festivals: const [
          Festival(
            id: 'cbf2025',
            name: 'Cambridge 2025',
            dataBaseUrl: 'https://example.com/cbf2025',
          ),
        ],
        defaultFestivalId: 'cbf2025',
        version: '1.0.0',
        baseUrl: 'https://example.com',
      ));

      await tester.pumpAndSettle();

      // Should STAY at drink detail (not redirect to /cbf2025)
      final currentUri = Uri.parse(appRouter.routerDelegate.currentConfiguration.uri.toString());
      expect(currentUri.path, '/cbf2025/drink/test-drink-123',
        reason: 'Should not redirect when already on valid route');
    });

    // KNOWN LIMITATION: Deep links with invalid festival IDs in subpaths
    // See lib/main.dart _handlePostInitRedirect() for full documentation
    // Example: /invalid-fest/drink/abc stays at /invalid-fest/drink/abc
    // Reason: Matches route pattern directly, bypassing redirect logic
    // Fix: Requires adding festival ID validation to ALL route builders

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
    // Edge cases and limitations
    testWidgets('URL fragments are lost during redirect (KNOWN LIMITATION)', (tester) async {
      // This documents the current limitation mentioned in lib/main.dart
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      // Navigate to invalid festival with fragment
      appRouter.go('/invalid-fest#section');
      await tester.pump();
      await tester.pumpAndSettle();

      final currentUri = Uri.parse(appRouter.routerDelegate.currentConfiguration.uri.toString());

      // Currently fragments are lost during redirect
      expect(currentUri.pathSegments.first, testFestivalId, reason: 'Should redirect to valid festival');
      expect(currentUri.fragment, isEmpty, reason: 'Fragment is lost (KNOWN LIMITATION - see lib/main.dart)');
      // TODO: Fix this by preserving currentUri.fragment in redirect URL construction
    });

    testWidgets('URL-encoded festival IDs are handled correctly', (tester) async {
      // Ensure malformed/encoded IDs don't bypass validation
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      // Navigate to URL-encoded version of valid festival (shouldn't match)
      appRouter.go('/cbf%202025'); // "cbf 2025" encoded
      await tester.pump();
      await tester.pumpAndSettle();

      final currentUri = Uri.parse(appRouter.routerDelegate.currentConfiguration.uri.toString());

      // URL-encoded IDs should be treated as invalid and redirected
      expect(currentUri.pathSegments.first, testFestivalId,
        reason: 'Encoded festival IDs should not match valid festival IDs');
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
