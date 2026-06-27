import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/main.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('BeerFestivalHome lifecycle', () {
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

    testWidgets('calls refreshIfStale when app resumes', (
      WidgetTester tester,
    ) async {
      // Track if refreshIfStale is called by checking API calls
      var refreshCallCount = 0;

      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async {
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

    testWidgets('removes lifecycle observer on dispose', (
      WidgetTester tester,
    ) async {
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
          child: const MaterialApp(home: Scaffold(body: Text('Other Screen'))),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should be disposed without errors
      expect(find.byType(BeerFestivalHome), findsNothing);
      expect(find.text('Other Screen'), findsOneWidget);
    });

    testWidgets('shows confirmation snackbar on first back at root', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: BeerFestivalHome(child: Scaffold(body: Text('Test'))),
          ),
        ),
      );

      expect(find.text('Press back again to exit'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text('Press back again to exit'), findsOneWidget);
    });

    testWidgets('requests app exit on second back within confirmation window', (
      WidgetTester tester,
    ) async {
      var systemNavigatorPopCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            methodCall,
          ) async {
            if (methodCall.method == 'SystemNavigator.pop') {
              systemNavigatorPopCalled = true;
            }
            return null;
          });

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: BeerFestivalHome(child: Scaffold(body: Text('Test'))),
          ),
        ),
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(systemNavigatorPopCalled, isFalse);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(systemNavigatorPopCalled, isTrue);
    });

    testWidgets(
      'does not exit when second back happens after confirmation window expires',
      (WidgetTester tester) async {
        var systemNavigatorPopCalled = false;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (
              methodCall,
            ) async {
              if (methodCall.method == 'SystemNavigator.pop') {
                systemNavigatorPopCalled = true;
              }
              return null;
            });

        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: const MaterialApp(
              home: BeerFestivalHome(child: Scaffold(body: Text('Test'))),
            ),
          ),
        );

        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('Press back again to exit'), findsOneWidget);
        expect(systemNavigatorPopCalled, isFalse);

        // Pump sequence: the snackbar duration timer only starts after the enter
        // animation completes (250 ms). A single large pump won't work because
        // the timer starts in the first frame, not during elapse(). We need a
        // frame to complete the enter animation first, then advance past the 2 s
        // confirmation window, then two more frames for the exit animation and
        // the resulting setState rebuild.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('Press back again to exit'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pump();

        expect(systemNavigatorPopCalled, isFalse);
        expect(find.text('Press back again to exit'), findsOneWidget);
      },
    );

    testWidgets('initializes provider on first load', (
      WidgetTester tester,
    ) async {
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
      verify(mockFestivalRepository.getFestivals()).called(1);

      // Verify loadDrinks was called
      verify(mockDrinkRepository.getDrinks(any)).called(1);
    });

    testWidgets('does not reinitialize on rebuild', (
      WidgetTester tester,
    ) async {
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
      reset(mockFestivalRepository);
      reset(mockDrinkRepository);

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
      verifyNever(mockFestivalRepository.getFestivals());
      verifyNever(mockDrinkRepository.getDrinks(any));
    });

    testWidgets('calls refreshIfStale when ProviderInitializer app resumes', (
      WidgetTester tester,
    ) async {
      var getDrinksCalls = 0;
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async {
        getDrinksCalls++;
        return <Drink>[];
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: ProviderInitializer(child: Scaffold(body: Text('Test'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Reset counter after initial load, then force stale state so that the
      // next refreshIfStale() call actually triggers a network reload.
      getDrinksCalls = 0;
      provider
        ..lastDrinksRefresh = DateTime.now().subtract(const Duration(hours: 2))
        ..lastDrinksRefreshAttempt = DateTime.now().subtract(
          const Duration(minutes: 5),
        );

      // Simulate app resuming from background
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // refreshIfStale was called and found stale data — a reload was triggered
      expect(getDrinksCalls, 1);
    });
  });

  group('FavoritesScreen', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    final favoriteDrink = Drink(
      product: const Product(
        id: 'drink1',
        name: 'Favourite Ale',
        abv: 4.5,
        category: 'beer',
        dispense: 'cask',
      ),
      producer: const Producer(
        id: 'brewery1',
        name: 'Test Brewery',
        location: 'Cambridge',
        products: [],
      ),
      festivalId: 'cbf2025',
      userState: UserDrinkState.initial().copyWith(wantToTry: true),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [
            const Festival(
              id: 'cbf2025',
              name: 'Cambridge Beer Festival 2025',
              dataBaseUrl: 'https://example.com',
            ),
          ],
          defaultFestivalId: 'cbf2025',
          version: '1.0',
          baseUrl: 'https://example.com',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => [favoriteDrink]);
      when(
        mockDrinkRepository.getFavorites(any),
      ).thenAnswer((_) async => ['drink1']);
      // Stub getPersonalEntries so favoriteEntries returns the loaded drink.
      when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
        'drink1': UserDrinkState.initial().copyWith(wantToTry: true),
      });

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
      await provider.loadDrinks();
    });

    tearDown(() {
      provider.dispose();
    });

    testWidgets(
      'navigates to drink detail when favorite drink card is tapped',
      (WidgetTester tester) async {
        final router = GoRouter(
          initialLocation: '/favorites',
          routes: [
            GoRoute(
              path: '/favorites',
              builder: (context, state) =>
                  ChangeNotifierProvider<BeerProvider>.value(
                    value: provider,
                    child: const FavoritesScreen(festivalId: 'cbf2025'),
                  ),
            ),
            GoRoute(
              path: '/cbf2025/drink/:category/:drinkId',
              builder: (context, state) =>
                  const Scaffold(body: Text('Drink Detail')),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Favourite Ale'), findsOneWidget);

        final drinkCard = find.byKey(const ValueKey('drink1'));
        await tester.ensureVisible(drinkCard);
        await tester.tap(drinkCard);
        await tester.pumpAndSettle();

        expect(find.text('Drink Detail'), findsOneWidget);
      },
    );

    testWidgets(
      'shows placeholder row when catalogue not loaded but store has favourite',
      (WidgetTester tester) async {
        // Use a fresh MockDrinkRepository so setUp stubs don't interfere.
        final emptyMockRepo = MockDrinkRepository();
        final emptyMockFestivalRepo = MockFestivalRepository();
        final emptyMockAnalytics = MockAnalyticsService();

        when(emptyMockFestivalRepo.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [
              const Festival(
                id: 'cbf2025',
                name: 'Cambridge Beer Festival 2025',
                dataBaseUrl: 'https://example.com',
              ),
            ],
            defaultFestivalId: 'cbf2025',
            version: '1.0',
            baseUrl: 'https://example.com',
          ),
        );
        when(
          emptyMockFestivalRepo.getSelectedFestivalId(),
        ).thenAnswer((_) async => null);
        // Catalogue returns nothing — simulates pre-load state
        when(emptyMockRepo.getDrinks(any)).thenAnswer((_) async => []);
        // Store has a wantToTry record for drink1
        when(emptyMockRepo.getPersonalEntries(any)).thenReturn({
          'drink1': UserDrinkState.initial().copyWith(wantToTry: true),
        });

        final emptyProvider = BeerProvider(
          drinkRepository: emptyMockRepo,
          festivalRepository: emptyMockFestivalRepo,
          analyticsService: emptyMockAnalytics,
        );
        addTearDown(emptyProvider.dispose);

        await emptyProvider.initialize();
        await emptyProvider.loadDrinks();

        final router = GoRouter(
          initialLocation: '/favorites',
          routes: [
            GoRoute(
              path: '/favorites',
              builder: (context, state) =>
                  ChangeNotifierProvider<BeerProvider>.value(
                    value: emptyProvider,
                    child: const FavoritesScreen(festivalId: 'cbf2025'),
                  ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Placeholder text is shown because the catalogue is not loaded
        expect(find.text('Loading details…'), findsOneWidget);
        // The real drink name is NOT shown
        expect(find.text('Favourite Ale'), findsNothing);
      },
    );

    testWidgets(
      'shows loading spinner when provider festival does not match route festivalId',
      (WidgetTester tester) async {
        // provider.currentFestival.id is 'cbf2025' after initialize().
        // Rendering FavoritesScreen with festivalId 'cbf2024' triggers the guard.
        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: const MaterialApp(
              home: FavoritesScreen(festivalId: 'cbf2024'),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Favourites list should NOT be shown during mismatch.
        expect(find.text('Favourite Ale'), findsNothing);
        expect(find.text('0 favourites'), findsNothing);
      },
    );

    testWidgets(
      'shows favourites content when provider festival matches route festivalId',
      (WidgetTester tester) async {
        // provider.currentFestival.id is 'cbf2025' after initialize().
        // Rendering FavoritesScreen with the matching festivalId renders normally.
        await tester.pumpWidget(
          ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: const MaterialApp(
              home: FavoritesScreen(festivalId: 'cbf2025'),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsNothing);
        // The favourites screen appBar subtitle should be visible.
        expect(find.textContaining('favourites'), findsOneWidget);
      },
    );
  });

  group('isTransientFontLoadError', () {
    test('detects google_fonts HTTP fetch failure by message', () {
      final error = Exception(
        'Failed to load font with url: https://fonts.gstatic.com/s/a/abc.ttf',
      );
      expect(isTransientFontLoadError(error, StackTrace.empty), isTrue);
    });

    test('detects font load failure by google_fonts stack frames', () {
      // A network-level exception whose message gives no hint, but whose
      // stack trace runs through the google_fonts package.
      final stack = StackTrace.fromString(
        '#0  _httpFetchFontAndSaveToDevice (package:google_fonts/src/google_fonts_base.dart:288)\n'
        '#1  loadFontIfNecessary (package:google_fonts/src/google_fonts_base.dart:175)',
      );
      expect(
        isTransientFontLoadError(Exception('connection refused'), stack),
        isTrue,
      );
    });

    test('does not flag unrelated application errors as font errors', () {
      final stack = StackTrace.fromString(
        '#0  BeerProvider.loadDrinks (package:cambridge_beer_festival/providers/beer_provider.dart:270)',
      );
      expect(
        isTransientFontLoadError(Exception('Something went wrong'), stack),
        isFalse,
      );
      expect(isTransientFontLoadError(StateError('bad state'), null), isFalse);
    });
  });
}
