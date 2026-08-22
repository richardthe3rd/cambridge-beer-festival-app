import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:cambridge_beer_festival/router.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';
import 'router_test_constants.dart';

// Test constants - single source of truth
const String testFestivalId2 = 'cbf2024';
const String invalidFestivalId = 'invalid-festival-123';
const String testDrinkId = 'test-drink-123';
const String testBreweryId = 'test-brewery-456';
const String aboutPath = '/about';

void main() {
  group('Router Configuration', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    setUp(() {
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();
      SharedPreferences.setMockInitialValues({});

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );

      // Mock default responses
      when(mockFestivalRepository.getFestivals()).thenAnswer(
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
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);

      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => <Drink>[]);
    });

    tearDown(() {
      provider.dispose();
    });

    testWidgets('buildAppRouter() returns independent instances, not a shared '
        'singleton', (tester) async {
      await provider.initialize();

      final router1 = buildAppRouter();
      final router2 = buildAppRouter();

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: router1),
        ),
      );
      await tester.pumpAndSettle();

      router1.go(aboutPath);
      await tester.pumpAndSettle();
      expect(
        router1.routerDelegate.currentConfiguration.uri.toString(),
        aboutPath,
      );

      // Swap the widget tree onto the second router instance. If
      // buildAppRouter() returned a shared singleton, router2 would
      // already be at aboutPath here because router1.go() would have
      // mutated shared navigation state.
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: router2),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        router2.routerDelegate.currentConfiguration.uri.toString(),
        isNot(aboutPath),
        reason:
            'buildAppRouter() must return independent GoRouter instances; '
            'a shared singleton would leak navigation state between them',
      );
    });

    testWidgets('router navigates to home page', (tester) async {
      // Initialize provider with festivals
      await provider.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );

      await tester.pumpAndSettle();

      // Should navigate to home (DrinksScreen) by default
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('router handles festival-scoped /favorites route', (
      tester,
    ) async {
      // Initialize provider with festivals
      await provider.initialize();
      final festivalId = provider.currentFestival.id;

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
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
      when(mockFestivalRepository.getFestivals()).thenAnswer(
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
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);

      await provider.initialize();
      expect(provider.currentFestival.id, 'cbf2025');

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
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

    testWidgets(
      'router redirects root path to festival home after async initialization',
      (tester) async {
        // DO NOT pre-initialize - this simulates the e2e scenario
        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );

        // Pump frames to allow async initialization to complete
        await tester.pumpAndSettle();

        // Should redirect from / to /cbf2025 after initialization
        final currentUri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(currentUri.pathSegments.isNotEmpty, true);
        expect(currentUri.pathSegments.first, 'cbf2025');
      },
    );

    testWidgets('router redirects invalid festival after async initialization', (
      tester,
    ) async {
      // DO NOT pre-initialize - this simulates the e2e scenario
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );

      // Navigate to invalid festival immediately (provider not initialized yet)
      appRouter.go('/invalid-festival-123');
      await tester.pump(); // Start the frame

      // Pump frames to allow async initialization AND redirect to complete
      await tester.pumpAndSettle();

      // Should redirect to current festival (cbf2025) after initialization
      final currentUri = Uri.parse(
        appRouter.routerDelegate.currentConfiguration.uri.toString(),
      );
      expect(currentUri.pathSegments.first, 'cbf2025');
      expect(provider.currentFestival.id, 'cbf2025');
    });

    testWidgets(
      'router redirects invalid festival with query params after async initialization',
      (tester) async {
        // DO NOT pre-initialize - this simulates the e2e scenario
        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );

        // Navigate to invalid festival with query params immediately
        appRouter.go('/invalid-fest?search=IPA&category=beer');
        await tester.pump();

        // Pump frames to allow async initialization AND redirect to complete
        await tester.pumpAndSettle();

        // Should redirect to cbf2025 and preserve query parameters
        final currentUri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(currentUri.pathSegments.first, 'cbf2025');
        expect(currentUri.queryParameters['search'], 'IPA');
        expect(currentUri.queryParameters['category'], 'beer');
      },
    );

    testWidgets(
      'deep link to valid route does NOT redirect after async initialization',
      (tester) async {
        // DO NOT pre-initialize - simulates deep link before app loads
        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );

        // Navigate to drink detail immediately (before init)
        appRouter.go('/$testFestivalId/drink/beer/$testDrinkId');
        await tester.pump();

        // Pump frames to allow async initialization to complete
        await tester.pumpAndSettle();

        // Should stay on drink detail route (valid festival ID)
        final currentUri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(currentUri.pathSegments.length, 4);
        expect(currentUri.pathSegments[0], testFestivalId);
        expect(currentUri.pathSegments[1], 'drink');
        expect(currentUri.pathSegments[2], 'beer');
        expect(currentUri.pathSegments[3], testDrinkId);
      },
    );

    testWidgets(
      'global /about route NOT redirected after async initialization',
      (tester) async {
        // Create a fresh router for this test to avoid state pollution
        final testRouter = GoRouter(
          initialLocation: '/about', // Start at /about
          debugLogDiagnostics: kDebugMode,
          routes: appRouter.configuration.routes,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: testRouter),
          ),
        );

        // Pump frames to allow async initialization to complete
        await tester.pumpAndSettle();

        // Should STAY at /about (NOT redirect to /cbf2025)
        final currentUri = Uri.parse(
          testRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(
          currentUri.path,
          '/about',
          reason: 'Global /about route should not be redirected',
        );
      },
    );

    // Note: Browser back/forward is handled by go_router's declarative API
    // and is tested in the e2e tests (test-e2e/routing.spec.ts).
    // Testing it at the widget level would require complex route history management
    // which is outside the scope of redirect logic testing.

    testWidgets('redirect handles API failure gracefully', (tester) async {
      // Mock API failure
      when(
        mockFestivalRepository.getFestivals(),
      ).thenThrow(Exception('API error'));
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);

      await tester.pumpAndSettle();

      // Should fall back to default festival despite API failure
      final currentUri = Uri.parse(
        appRouter.routerDelegate.currentConfiguration.uri.toString(),
      );
      expect(currentUri.pathSegments.isNotEmpty, true);
      expect(
        currentUri.pathSegments.first,
        DefaultFestivals.all.firstWhere((f) => f.isActive).id,
        reason: 'Should use active hardcoded festival when API fails',
      );
    });

    testWidgets('redirect handles empty festivals list', (tester) async {
      // Mock empty festivals list
      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: const [],
          defaultFestivalId:
              'cbf2025', // Still provide default even with empty list
          version: '1.0.0',
          baseUrl: 'https://example.com',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );

      await tester.pumpAndSettle();

      // Should use hardcoded default festival
      final currentUri = Uri.parse(
        appRouter.routerDelegate.currentConfiguration.uri.toString(),
      );
      expect(currentUri.pathSegments.isNotEmpty, true);
      expect(
        currentUri.pathSegments.first,
        DefaultFestivals.all.firstWhere((f) => f.isActive).id,
        reason: 'Should use active hardcoded festival when registry is empty',
      );
    });

    testWidgets('multiple rapid navigations before init completes', (
      tester,
    ) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
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
      final currentUri = Uri.parse(
        appRouter.routerDelegate.currentConfiguration.uri.toString(),
      );
      expect(currentUri.pathSegments.first, 'cbf2025');
      expect(
        tester.takeException(),
        isNull,
        reason: 'Should not throw exceptions during rapid navigation',
      );
    });

    testWidgets('festival switch during navigation after init', (tester) async {
      // Setup multiple festivals
      when(mockFestivalRepository.getFestivals()).thenAnswer(
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
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );

      // Navigate to cbf2024 before init completes
      appRouter.go('/cbf2024');
      await tester.pump();

      // Let init complete
      await tester.pumpAndSettle();

      // Provider should switch to cbf2024 (via postFrameCallback)
      expect(
        provider.currentFestival.id,
        'cbf2024',
        reason: 'Provider should switch to festival in URL',
      );
    });

    testWidgets('navigation during slow initialization', (tester) async {
      // Create a completer to control initialization timing
      final completer = Completer<FestivalsResponse>();
      when(
        mockFestivalRepository.getFestivals(),
      ).thenAnswer((_) => completer.future);
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);

      // Start showing loading state
      await tester.pump();

      // User navigates to drink detail DURING initialization
      appRouter.go('/cbf2025/drink/beer/test-drink-123');
      await tester.pump();

      // Now complete initialization
      completer.complete(
        FestivalsResponse(
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
        ),
      );

      await tester.pumpAndSettle();

      // Should STAY at drink detail (not redirect to /cbf2025)
      final currentUri = Uri.parse(
        appRouter.routerDelegate.currentConfiguration.uri.toString(),
      );
      expect(
        currentUri.path,
        '/cbf2025/drink/beer/test-drink-123',
        reason: 'Should not redirect when already on valid route',
      );
    });

    testWidgets(
      'root `/` route shows loading indicator while provider initializes (regression #386)',
      (tester) async {
        // Delay festival loading so we can observe the intermediate loading state.
        final completer = Completer<FestivalsResponse>();
        when(
          mockFestivalRepository.getFestivals(),
        ).thenAnswer((_) => completer.future);
        when(
          mockFestivalRepository.getSelectedFestivalId(),
        ).thenAnswer((_) async => null);

        // Fresh router at `/` to avoid state pollution from other tests.
        final testRouter = GoRouter(
          initialLocation: '/',
          debugLogDiagnostics: kDebugMode,
          routes: appRouter.configuration.routes,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: testRouter),
          ),
        );

        // Before initialization completes the redirect returns null and the
        // loading builder renders — this is the fix for issue #386.
        await tester.pump();
        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
          reason: 'Loading builder must render while provider is initializing',
        );

        // Unblock initialization and let the post-init redirect fire.
        completer.complete(
          FestivalsResponse(
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
          ),
        );
        await tester.pumpAndSettle();

        // Should have redirected away from `/`.
        final currentUri = Uri.parse(
          testRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(currentUri.pathSegments.first, 'cbf2025');
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    // KNOWN LIMITATION: Deep links with invalid festival IDs in subpaths
    // See lib/main.dart _handlePostInitRedirect() for full documentation
    // Example: /invalid-fest/drink/beer/abc stays at /invalid-fest/drink/beer/abc
    // Reason: Matches route pattern directly, bypassing redirect logic
    // Fix: Requires adding festival ID validation to ALL route builders

    testWidgets(
      'router redirects invalid festival ID (pre-initialized provider)',
      (tester) async {
        await provider.initialize();
        final currentFestival = provider.currentFestival.id;

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );

        await tester.pumpAndSettle();

        // Try to navigate to invalid festival ID
        appRouter.go('/invalid-festival-123');
        await tester.pumpAndSettle();

        // Should redirect to current festival
        expect(provider.currentFestival.id, currentFestival);
      },
    );

    testWidgets(
      'router preserves query parameters when redirecting invalid festival ID',
      (tester) async {
        await provider.initialize();
        final currentFestival = provider.currentFestival.id;

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );

        await tester.pumpAndSettle();

        // Try to navigate to invalid festival with query parameters
        appRouter.go('/invalid-festival-123?search=IPA&category=beer');
        await tester.pumpAndSettle();

        // Should redirect to current festival and preserve query params
        final currentUri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(currentUri.pathSegments.first, currentFestival);
        expect(currentUri.queryParameters['search'], 'IPA');
        expect(currentUri.queryParameters['category'], 'beer');
      },
    );
    // Edge cases and limitations
    testWidgets('URL fragments survive the invalid-festival redirect', (
      tester,
    ) async {
      // Previously a known limitation: the redirect rebuilt the path and
      // dropped the fragment. _redirectToCurrentFestival now carries it over.
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );

      appRouter.go('/invalid-fest#section');
      await tester.pump();
      await tester.pumpAndSettle();

      final currentUri = Uri.parse(
        appRouter.routerDelegate.currentConfiguration.uri.toString(),
      );

      expect(
        currentUri.pathSegments.first,
        testFestivalId,
        reason: 'Should redirect to valid festival',
      );
      expect(
        currentUri.fragment,
        'section',
        reason: 'Fragment must survive the redirect',
      );
    });

    testWidgets('URL-encoded festival IDs are handled correctly', (
      tester,
    ) async {
      // Ensure malformed/encoded IDs don't bypass validation
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );

      // Navigate to URL-encoded version of valid festival (shouldn't match)
      appRouter.go('/cbf%202025'); // "cbf 2025" encoded
      await tester.pump();
      await tester.pumpAndSettle();

      final currentUri = Uri.parse(
        appRouter.routerDelegate.currentConfiguration.uri.toString(),
      );

      // URL-encoded IDs should be treated as invalid and redirected
      expect(
        currentUri.pathSegments.first,
        testFestivalId,
        reason: 'Encoded festival IDs should not match valid festival IDs',
      );
    });

    // Regression tests for issue #266: cold-load / browser-refresh uses wrong festival
    testWidgets(
      'cold load of non-default festival URL syncs provider (regression #266)',
      (tester) async {
        when(mockFestivalRepository.getFestivals()).thenAnswer(
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
        when(
          mockFestivalRepository.getSelectedFestivalId(),
        ).thenAnswer((_) async => null);

        // True cold load: router starts at cbf2024 before any initialization
        final testRouter = GoRouter(
          initialLocation: '/cbf2024',
          debugLogDiagnostics: kDebugMode,
          routes: appRouter.configuration.routes,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: testRouter),
          ),
        );

        await tester.pumpAndSettle();

        // Provider must be synced to the URL festival, not the default
        expect(
          provider.currentFestival.id,
          'cbf2024',
          reason:
              'Cold-loaded festival URL must sync the provider (issue #266)',
        );
        expect(find.text('Cambridge 2024'), findsOneWidget);
        expect(find.text('Cambridge 2025'), findsNothing);
      },
    );

    testWidgets(
      'cold load of drink deep link from non-default festival syncs provider (regression #266)',
      (tester) async {
        when(mockFestivalRepository.getFestivals()).thenAnswer(
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
        when(
          mockFestivalRepository.getSelectedFestivalId(),
        ).thenAnswer((_) async => null);

        // True cold load: shared drink link from a non-default festival
        final testRouter = GoRouter(
          initialLocation: '/cbf2024/drink/beer/$testDrinkId',
          debugLogDiagnostics: kDebugMode,
          routes: appRouter.configuration.routes,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: testRouter),
          ),
        );

        await tester.pumpAndSettle();

        // Provider must switch to cbf2024 so getDrinkById searches the right festival
        expect(
          provider.currentFestival.id,
          'cbf2024',
          reason:
              'Cold-loaded deep link must sync provider to the URL festival (issue #266)',
        );
      },
    );

    testWidgets(
      'invalid festival ID in detail routes redirects to current festival equivalent',
      (tester) async {
        await provider.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );
        await tester.pumpAndSettle();

        // Drink route
        appRouter.go('/$invalidFestivalId/drink/beer/$testDrinkId');
        await tester.pumpAndSettle();
        var uri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(uri.pathSegments[0], testFestivalId);
        expect(uri.pathSegments[1], 'drink');
        expect(uri.pathSegments[2], 'beer');
        expect(
          uri.pathSegments[3],
          testDrinkId,
          reason:
              'Invalid festival in drink route should redirect, preserving category and drink ID',
        );

        // Brewery route
        appRouter.go('/$invalidFestivalId/brewery/$testBreweryId');
        await tester.pumpAndSettle();
        uri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(uri.pathSegments[0], testFestivalId);
        expect(uri.pathSegments[1], 'brewery');
        expect(
          uri.pathSegments[2],
          testBreweryId,
          reason:
              'Invalid festival in brewery route should redirect, preserving brewery ID',
        );

        // Style route
        appRouter.go('/$invalidFestivalId/style/IPA');
        await tester.pumpAndSettle();
        uri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(uri.pathSegments[0], testFestivalId);
        expect(uri.pathSegments[1], 'style');

        // Info route
        appRouter.go('/$invalidFestivalId/info');
        await tester.pumpAndSettle();
        uri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(uri.pathSegments[0], testFestivalId);
        expect(
          uri.pathSegments[1],
          'info',
          reason: 'Invalid festival in info route should redirect',
        );

        // Favorites route
        appRouter.go('/$invalidFestivalId/favorites');
        await tester.pumpAndSettle();
        uri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(uri.pathSegments[0], testFestivalId);
        expect(
          uri.pathSegments[1],
          'favorites',
          reason: 'Invalid festival in favorites route should redirect',
        );
      },
    );

    testWidgets(
      'favorites route with different festival switches provider (hot navigation)',
      (tester) async {
        when(mockFestivalRepository.getFestivals()).thenAnswer(
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
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );
        await tester.pumpAndSettle();

        appRouter.go('/cbf2024/favorites');
        await tester.pumpAndSettle();

        expect(
          provider.currentFestival.id,
          'cbf2024',
          reason:
              'Navigating to favorites of a different festival should switch provider',
        );
      },
    );

    testWidgets(
      'brewery, style and info routes are reachable for valid festival',
      (tester) async {
        await provider.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );
        await tester.pumpAndSettle();

        // Brewery route
        appRouter.go('/$testFestivalId/brewery/$testBreweryId');
        await tester.pumpAndSettle();
        var uri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(uri.pathSegments[0], testFestivalId);
        expect(uri.pathSegments[1], 'brewery');

        // Style route
        appRouter.go('/$testFestivalId/style/IPA');
        await tester.pumpAndSettle();
        uri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(uri.pathSegments[0], testFestivalId);
        expect(uri.pathSegments[1], 'style');

        // Info route
        appRouter.go('/$testFestivalId/info');
        await tester.pumpAndSettle();
        uri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(uri.pathSegments[0], testFestivalId);
        expect(uri.pathSegments[1], 'info');
      },
    );

    testWidgets(
      'style route with illegal percent encoding does not crash the build',
      (tester) async {
        await provider.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );
        await tester.pumpAndSettle();

        // A malformed URL (e.g. an old bookmark with a stray `%`) previously
        // crashed the build via Uri.decodeComponent throwing.
        appRouter.go('/$testFestivalId/style/50%');
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(StyleScreen), findsOneWidget);
      },
    );

    testWidgets(
      'navigating to drink detail updates URL with category and drink ID',
      (tester) async {
        await provider.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );
        await tester.pumpAndSettle();

        // Start at drinks list
        appRouter.go('/$testFestivalId');
        await tester.pumpAndSettle();

        // Exercises go()'s URL-update behavior directly (used for root/tab
        // navigation, e.g. bottom nav in main.dart) — NOT what navigateToRoute()
        // calls today; navigateToRoute() always uses push(), covered by the
        // 'push()ing a drink detail route...' test below.
        const category = 'beer';
        appRouter.go('/$testFestivalId/drink/$category/$testDrinkId');
        await tester.pumpAndSettle();

        // URL must update to the full /:festivalId/drink/:category/:id deep-link format
        final uri = Uri.parse(
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
        );
        expect(
          uri.pathSegments.length,
          4,
          reason:
              'Drink detail URL must include festivalId, "drink", category, and drinkId',
        );
        expect(uri.pathSegments[0], testFestivalId);
        expect(uri.pathSegments[1], 'drink');
        expect(uri.pathSegments[2], category);
        expect(
          uri.pathSegments[3],
          testDrinkId,
          reason:
              'URL must match deep-link format so shared/bookmarked links work',
        );
      },
    );

    testWidgets(
      'push()ing a drink detail route updates the URL via optionURLReflectsImperativeAPIs',
      (tester) async {
        // Proves the fix on the production appRouter (not just a standalone
        // fixture): appRouter is built by buildAppRouter() in router.dart,
        // a pure factory with no static side effect. The flag is set once
        // in main() instead, which this test never calls (main() is wrapped
        // in coverage:ignore-start/-end and no test invokes it) — so this
        // test sets the flag itself, matching the defensive pattern at
        // test/utils/navigation_helpers_test.dart.
        GoRouter.optionURLReflectsImperativeAPIs = true;

        await provider.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );
        await tester.pumpAndSettle();

        // Start at drinks list
        appRouter.go('/$testFestivalId');
        await tester.pumpAndSettle();

        const category = 'beer';
        unawaited(
          appRouter.push('/$testFestivalId/drink/$category/$testDrinkId'),
        );
        await tester.pumpAndSettle();

        // routeInformationProvider.value.uri is what actually drives the
        // browser URL bar for imperative navigation (push/pop), unlike
        // routerDelegate.currentConfiguration.uri used above for go().
        final uri = appRouter.routeInformationProvider.value.uri;
        expect(
          uri.pathSegments.length,
          4,
          reason:
              'Drink detail URL must include festivalId, "drink", category, and drinkId',
        );
        expect(uri.pathSegments[0], testFestivalId);
        expect(uri.pathSegments[1], 'drink');
        expect(uri.pathSegments[2], category);
        expect(
          uri.pathSegments[3],
          testDrinkId,
          reason:
              'URL must match deep-link format so shared/bookmarked links work',
        );
      },
    );

    // go_router hands back *decoded* path parameters (match.dart's
    // Uri.decodeComponent), so a redirect that rebuilds the path by string
    // interpolation silently loses the encoding: a '/' reappears as a path
    // separator, a '?' starts a query, a '#' starts a fragment. Every
    // festival-scoped route rebuilds its path on an invalid festival id, so
    // this has to hold for all of them.
    testWidgets(
      'invalid-festival redirect preserves percent-encoded path parameters',
      (tester) async {
        await provider.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );
        await tester.pumpAndSettle();

        Uri currentUri() => appRouter.routerDelegate.currentConfiguration.uri;

        // A brewery id containing '?' must survive as one path segment.
        appRouter.go('/$invalidFestivalId/brewery/what%3Fnow');
        await tester.pumpAndSettle();
        expect(currentUri().pathSegments, [
          testFestivalId,
          'brewery',
          'what?now',
        ], reason: 'A ? in a brewery id must not become a query string');
        expect(currentUri().hasQuery, isFalse);

        // A style containing '/' (e.g. "Porter/Stout", encoded by
        // buildStylePath) must stay a single segment, not split the route.
        appRouter.go('/$invalidFestivalId/style/porter%2Fstout');
        await tester.pumpAndSettle();
        expect(currentUri().pathSegments, [
          testFestivalId,
          'style',
          'porter/stout',
        ], reason: 'A / in a style name must not split into two segments');

        // A '#' must not become a fragment.
        appRouter.go('/$invalidFestivalId/brewery/hash%23tag');
        await tester.pumpAndSettle();
        expect(currentUri().pathSegments, [
          testFestivalId,
          'brewery',
          'hash#tag',
        ]);
        expect(currentUri().hasFragment, isFalse);
      },
    );

    // go_router decodes path parameters before handing them to the builder, so
    // decoding again turns a style whose name literally contains a percent
    // escape into a different string.
    testWidgets('style route does not double-decode its path parameter', (
      tester,
    ) async {
      await provider.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      await tester.pumpAndSettle();

      // '%2520' decodes once to the literal text '%20'.
      appRouter.go('/$testFestivalId/style/a%2520b');
      await tester.pumpAndSettle();

      final screen = tester.widget<StyleScreen>(find.byType(StyleScreen));
      expect(
        screen.style,
        'a%20b',
        reason: 'Decoding a second time would yield "a b"',
      );
    });

    // Only the /:festivalId route used to preserve the query string; the five
    // nested routes dropped it. Nothing pinned that difference, so it was
    // drift rather than a decision.
    testWidgets(
      'invalid-festival redirect preserves the query string on nested routes',
      (tester) async {
        await provider.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );
        await tester.pumpAndSettle();

        for (final path in [
          'drink/beer/$testDrinkId',
          'brewery/$testBreweryId',
          'style/ipa',
          'info',
          'favorites',
        ]) {
          appRouter.go('/$invalidFestivalId/$path?utm=email&ref=friend');
          await tester.pumpAndSettle();

          final uri = appRouter.routerDelegate.currentConfiguration.uri;
          expect(uri.pathSegments.first, testFestivalId);
          expect(uri.queryParameters, {
            'utm': 'email',
            'ref': 'friend',
          }, reason: 'Query params must survive the redirect on /$path');
        }
      },
    );

    testWidgets('invalid-festival redirect preserves the URL fragment', (
      tester,
    ) async {
      await provider.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      await tester.pumpAndSettle();

      appRouter.go('/$invalidFestivalId/info?a=1#sec%20tion');
      await tester.pumpAndSettle();

      final uri = appRouter.routerDelegate.currentConfiguration.uri;
      expect(uri.pathSegments, [testFestivalId, 'info']);
      expect(uri.query, 'a=1');
      expect(
        uri.fragment,
        'sec%20tion',
        reason: 'Uri.fragment is the raw form; it must round-trip unchanged',
      );
    });
  });

  group('Router Navigation Paths (Phase 1 - Festival-scoped)', () {
    const festivalId = 'cbf2025';

    test('drink detail route parses category and ID correctly', () {
      final uri = Uri.parse('/$festivalId/drink/beer/test-drink-123');
      expect(uri.pathSegments.length, 4);
      expect(uri.pathSegments[0], festivalId);
      expect(uri.pathSegments[1], 'drink');
      expect(uri.pathSegments[2], 'beer');
      expect(uri.pathSegments[3], 'test-drink-123');
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
      final uri = Uri.parse('/$festivalId/drink/beer/abc123');
      expect(uri.path, '/$festivalId/drink/beer/abc123');
      expect(uri.pathSegments[0], festivalId);
      expect(uri.pathSegments[2], 'beer');
      expect(uri.pathSegments[3], 'abc123');
    });

    test('brewery detail path is festival-scoped', () {
      final uri = Uri.parse('/$festivalId/brewery/xyz789');
      expect(uri.path, '/$festivalId/brewery/xyz789');
      expect(uri.pathSegments[0], festivalId);
      expect(uri.pathSegments[2], 'xyz789');
    });

    test('style path is festival-scoped with lowercase canonical format', () {
      final uri = Uri.parse('/$festivalId/style/ipa');
      expect(uri.path, '/$festivalId/style/ipa');
      expect(uri.pathSegments[0], festivalId);
      expect(uri.pathSegments[2], 'ipa');
    });
  });
}
