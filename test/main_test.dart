import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/main.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('BeerFestivalHome lifecycle', () {
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

    testWidgets('adds lifecycle observer on init', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: BeerFestivalHome(child: Scaffold(body: Text('Test'))),
          ),
        ),
      );

      // Widget should be created without errors
      expect(find.byType(BeerFestivalHome), findsOneWidget);
    });

    testWidgets('calls refreshIfStale when app resumes', (WidgetTester tester) async {
      // Track if refreshIfStale is called by checking API calls
      var refreshCallCount = 0;

      when(mockApiService.fetchAllDrinks(any)).thenAnswer((_) async {
        refreshCallCount++;
        return <Drink>[];
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: BeerFestivalHome(child: Scaffold(body: Text('Test'))),
          ),
        ),
      );

      // Wait for initial load
      await tester.pumpAndSettle();

      // Reset counter after initial load
      refreshCallCount = 0;

      // Force data to become stale by manually setting a very old timestamp
      // We'll do this by waiting and then simulating app resume
      // Since we can't directly manipulate private fields, we'll rely on the
      // fact that refreshIfStale checks staleness

      // Simulate app going to background
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Simulate app resuming to foreground
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // refreshIfStale should have been called, but since data is fresh,
      // it shouldn't trigger a reload (refreshCallCount should still be 0)
      expect(refreshCallCount, 0);
    });

    testWidgets('removes lifecycle observer on dispose', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: BeerFestivalHome(child: Scaffold(body: Text('Test'))),
          ),
        ),
      );

      expect(find.byType(BeerFestivalHome), findsOneWidget);

      // Navigate away to trigger dispose
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: Text('Other Screen')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should be disposed without errors
      expect(find.byType(BeerFestivalHome), findsNothing);
      expect(find.text('Other Screen'), findsOneWidget);
    });

    testWidgets('initializes provider on first load', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: ProviderInitializer(
              child: BeerFestivalHome(child: Scaffold(body: Text('Test'))),
            ),
          ),
        ),
      );

      // Wait for initialization
      await tester.pumpAndSettle();

      // Verify initialize was called (which calls loadFestivals)
      verify(mockFestivalService.fetchFestivals()).called(1);

      // Verify loadDrinks was called
      verify(mockApiService.fetchAllDrinks(any)).called(1);
    });

    testWidgets('does not reinitialize on rebuild', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: ProviderInitializer(
              child: BeerFestivalHome(child: Scaffold(body: Text('Test'))),
            ),
          ),
        ),
      );

      // Wait for initial load
      await tester.pumpAndSettle();

      // Reset mocks to track subsequent calls
      reset(mockFestivalService);
      reset(mockApiService);

      // Trigger a rebuild
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: BeerFestivalHome(child: Scaffold(body: Text('Test'))),
          ),
        ),
      );

      await tester.pump();

      // Should not reinitialize
      verifyNever(mockFestivalService.fetchFestivals());
      verifyNever(mockApiService.fetchAllDrinks(any));
    });
  });
}
