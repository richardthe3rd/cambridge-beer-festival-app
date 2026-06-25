import 'dart:async';

import 'package:cambridge_beer_festival/domain/repositories/repositories.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'festival_menu_sheets_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<DrinkRepository>(),
  MockSpec<FestivalRepository>(),
  MockSpec<AnalyticsService>(),
])
void main() {
  group('FestivalSelectorSheet', () {
    late BeerProvider provider;
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late Festival testFestival;
    late List<Festival> testFestivals;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      testFestival = Festival(
        id: 'test-2024',
        name: 'Test Beer Festival 2024',
        dataBaseUrl: 'https://example.com',
        startDate: DateTime(2024, 5, 20),
        endDate: DateTime(2024, 5, 25),
        location: 'Test Location',
        availableBeverageTypes: const ['beer', 'cider'],
      );

      testFestivals = [testFestival];

      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: testFestivals,
          defaultFestivalId: testFestival.id,
          version: '1.0.0',
          baseUrl: 'https://data.cambeerfestival.app',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );

      await provider.initialize();
    });

    Widget buildTestWidget({ThemeData? theme}) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: FestivalSelectorSheet(provider: provider),
          ),
        ),
      );
    }

    testWidgets('displays festival browser title', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Browse Festivals'), findsOneWidget);
      expect(
        find.text('Choose a festival to browse its drinks'),
        findsOneWidget,
      );
    });

    testWidgets('displays festival cards when festivals are loaded', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(FestivalCard), findsOneWidget);
      expect(find.text('Test Beer Festival 2024'), findsOneWidget);
    });

    testWidgets('marks current festival as selected', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final cardFinder = find.byType(FestivalCard);
      expect(cardFinder, findsOneWidget);

      final card = tester.widget<FestivalCard>(cardFinder);
      expect(card.isSelected, isTrue);
    });

    testWidgets('calls setFestival when festival tapped', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      final initialFestival = provider.currentFestival;

      await tester.tap(find.byType(FestivalCard));
      await tester.pumpAndSettle();

      // Should call setFestival (which in test will be same festival)
      expect(provider.currentFestival, equals(initialFestival));
    });

    tearDown(() => provider.dispose());

    testWidgets('has correct semantics for screen readers', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byType(FestivalCard),
              matching: find.byType(Semantics),
            )
            .first,
      );

      expect(semantics.properties.label, contains('Test Beer Festival 2024'));
      expect(semantics.properties.button, isTrue);
    });

    testWidgets('uses high-contrast drag handle color in light theme', (
      tester,
    ) async {
      final lightTheme = buildAppTheme(Brightness.light);
      await tester.pumpWidget(buildTestWidget(theme: lightTheme));

      final handleContainer = tester.widget<Container>(
        find.byKey(const Key('festival_selector_drag_handle')),
      );
      final decoration = handleContainer.decoration! as BoxDecoration;

      expect(decoration.color, lightTheme.colorScheme.onSurfaceVariant);
    });

    testWidgets('shows loading indicator when festivals are loading', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final drinkRepo = MockDrinkRepository();
      final festivalRepo = MockFestivalRepository();
      final analytics = MockAnalyticsService();
      final completer = Completer<FestivalsResponse>();

      when(festivalRepo.getFestivals()).thenAnswer((_) => completer.future);
      when(drinkRepo.getDrinks(any)).thenAnswer((_) async => []);

      final loadingProvider = BeerProvider(
        drinkRepository: drinkRepo,
        festivalRepository: festivalRepo,
        analyticsService: analytics,
      );
      addTearDown(loadingProvider.dispose);

      // loadFestivals sets _isFestivalsLoading = true synchronously before awaiting
      unawaited(loadingProvider.loadFestivals());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FestivalSelectorSheet(provider: loadingProvider),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        FestivalsResponse(
          festivals: [],
          defaultFestivalId: '',
          version: '1.0.0',
          baseUrl: 'https://data.cambeerfestival.app',
        ),
      );
      // Don't pumpAndSettle — FestivalSelectorSheet is a StatelessWidget and
      // won't rebuild, so CircularProgressIndicator keeps animating indefinitely.
      await tester.pump();
    });

    testWidgets('shows error state when festival loading fails', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final drinkRepo = MockDrinkRepository();
      final festivalRepo = MockFestivalRepository();
      final analytics = MockAnalyticsService();

      when(festivalRepo.getFestivals()).thenThrow(Exception('Network error'));
      when(festivalRepo.getSelectedFestivalId()).thenAnswer((_) async => null);
      when(drinkRepo.getDrinks(any)).thenAnswer((_) async => []);

      final errorProvider = BeerProvider(
        drinkRepository: drinkRepo,
        festivalRepository: festivalRepo,
        analyticsService: analytics,
      );
      addTearDown(errorProvider.dispose);

      await errorProvider.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FestivalSelectorSheet(provider: errorProvider)),
        ),
      );

      expect(find.text('Failed to load festivals'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button triggers loadFestivals and clears error', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final drinkRepo = MockDrinkRepository();
      final festivalRepo = MockFestivalRepository();
      final analytics = MockAnalyticsService();

      var callCount = 0;
      when(festivalRepo.getFestivals()).thenAnswer((_) async {
        if (callCount++ == 0) throw Exception('Network error');
        return FestivalsResponse(
          festivals: [],
          defaultFestivalId: '',
          version: '1.0.0',
          baseUrl: 'https://data.cambeerfestival.app',
        );
      });
      when(festivalRepo.getSelectedFestivalId()).thenAnswer((_) async => null);
      when(drinkRepo.getDrinks(any)).thenAnswer((_) async => []);

      final retryProvider = BeerProvider(
        drinkRepository: drinkRepo,
        festivalRepository: festivalRepo,
        analyticsService: analytics,
      );
      addTearDown(retryProvider.dispose);

      await retryProvider.initialize();
      expect(retryProvider.festivalsError, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FestivalSelectorSheet(provider: retryProvider)),
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retryProvider.festivalsError, isNull);
    });

    testWidgets('shows empty state when no festivals are available', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final drinkRepo = MockDrinkRepository();
      final festivalRepo = MockFestivalRepository();
      final analytics = MockAnalyticsService();

      when(festivalRepo.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [],
          defaultFestivalId: '',
          version: '1.0.0',
          baseUrl: 'https://data.cambeerfestival.app',
        ),
      );
      when(festivalRepo.getSelectedFestivalId()).thenAnswer((_) async => null);
      when(drinkRepo.getDrinks(any)).thenAnswer((_) async => []);

      final emptyProvider = BeerProvider(
        drinkRepository: drinkRepo,
        festivalRepository: festivalRepo,
        analyticsService: analytics,
      );
      addTearDown(emptyProvider.dispose);

      await emptyProvider.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FestivalSelectorSheet(provider: emptyProvider)),
        ),
      );

      expect(find.text('No festivals available'), findsOneWidget);
      expect(find.byIcon(Icons.festival_outlined), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('refresh button triggers loadFestivals in empty state', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final drinkRepo = MockDrinkRepository();
      final festivalRepo = MockFestivalRepository();
      final analytics = MockAnalyticsService();

      var callCount = 0;
      when(festivalRepo.getFestivals()).thenAnswer((_) async {
        callCount++;
        return FestivalsResponse(
          festivals: callCount > 1 ? [testFestival] : [],
          defaultFestivalId: callCount > 1 ? testFestival.id : '',
          version: '1.0.0',
          baseUrl: 'https://data.cambeerfestival.app',
        );
      });
      when(festivalRepo.getSelectedFestivalId()).thenAnswer((_) async => null);
      when(drinkRepo.getDrinks(any)).thenAnswer((_) async => []);

      final emptyProvider = BeerProvider(
        drinkRepository: drinkRepo,
        festivalRepository: festivalRepo,
        analyticsService: analytics,
      );
      addTearDown(emptyProvider.dispose);

      await emptyProvider.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FestivalSelectorSheet(provider: emptyProvider)),
        ),
      );

      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      expect(emptyProvider.sortedFestivals, isNotEmpty);
    });

    testWidgets(
      'semantics label includes currently selected for current festival',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label?.contains(testFestival.name) ??
                    false) &&
                (widget.properties.label?.contains('currently selected') ??
                    false),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'semantics label omits currently selected for non-current festival',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final drinkRepo = MockDrinkRepository();
        final festivalRepo = MockFestivalRepository();
        final analytics = MockAnalyticsService();

        final otherFestival = Festival(
          id: 'other-2023',
          name: 'Other Festival 2023',
          dataBaseUrl: 'https://example.com',
          startDate: DateTime(2023, 5, 15),
          endDate: DateTime(2023, 5, 20),
        );

        when(festivalRepo.getFestivals()).thenAnswer(
          (_) async => FestivalsResponse(
            festivals: [testFestival, otherFestival],
            defaultFestivalId: testFestival.id,
            version: '1.0.0',
            baseUrl: 'https://data.cambeerfestival.app',
          ),
        );
        when(
          festivalRepo.getSelectedFestivalId(),
        ).thenAnswer((_) async => testFestival.id);
        when(drinkRepo.getDrinks(any)).thenAnswer((_) async => []);

        final twoFestivalProvider = BeerProvider(
          drinkRepository: drinkRepo,
          festivalRepository: festivalRepo,
          analyticsService: analytics,
        );
        addTearDown(twoFestivalProvider.dispose);
        await twoFestivalProvider.initialize();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FestivalSelectorSheet(provider: twoFestivalProvider),
            ),
          ),
        );

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label?.contains('Other Festival 2023') ??
                    false) &&
                !(widget.properties.label?.contains('currently selected') ??
                    false),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('FestivalCard', () {
    late Festival testFestival;
    late List<Festival> testFestivals;
    bool onTapCalled = false;
    bool onInfoTapCalled = false;

    setUp(() {
      onTapCalled = false;
      onInfoTapCalled = false;

      testFestival = Festival(
        id: 'test-2024',
        name: 'Test Beer Festival 2024',
        dataBaseUrl: 'https://example.com',
        startDate: DateTime(2024, 5, 20),
        endDate: DateTime(2024, 5, 25),
        location: 'Test Location',
        availableBeverageTypes: const ['beer', 'cider'],
      );

      testFestivals = [testFestival];
    });

    Widget buildTestWidget({bool isSelected = false}) {
      return MaterialApp(
        home: Scaffold(
          body: FestivalCard(
            festival: testFestival,
            sortedFestivals: testFestivals,
            isSelected: isSelected,
            onTap: () => onTapCalled = true,
            onInfoTap: () => onInfoTapCalled = true,
          ),
        ),
      );
    }

    testWidgets('displays festival name and dates', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Test Beer Festival 2024'), findsOneWidget);
      expect(find.text('May 20-25, 2024'), findsOneWidget);
    });

    testWidgets('displays location when available', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Test Location'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets('shows check icon when selected', (tester) async {
      await tester.pumpWidget(buildTestWidget(isSelected: true));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    });

    testWidgets('shows unchecked icon when not selected', (tester) async {
      await tester.pumpWidget(buildTestWidget(isSelected: false));

      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('calls onTap when card is tapped', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(onTapCalled, isTrue);
    });

    testWidgets('calls onInfoTap when info button is tapped', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(onInfoTapCalled, isTrue);
    });

    testWidgets('displays beverage types when available', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Beer'), findsOneWidget);
      expect(find.text('Cider'), findsOneWidget);
    });

    testWidgets('shows MOST RECENT badge for the only past festival', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('MOST RECENT'), findsOneWidget);
    });

    testWidgets(
      'shows PAST badge for older festival when a newer past one exists',
      (tester) async {
        final newerFestival = Festival(
          id: 'newer-2025',
          name: 'Newer Festival 2025',
          dataBaseUrl: 'https://example.com',
          startDate: DateTime(2025, 5, 20),
          endDate: DateTime(2025, 5, 25),
        );
        final bothFestivals = Festival.sortByDate([
          newerFestival,
          testFestival,
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FestivalCard(
                festival: testFestival,
                sortedFestivals: bothFestivals,
                isSelected: false,
                onTap: () {},
                onInfoTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('PAST'), findsOneWidget);
      },
    );

    testWidgets('shows LIVE badge for a currently running festival', (
      tester,
    ) async {
      final liveFestival = Festival(
        id: 'live-now',
        name: 'Live Festival',
        dataBaseUrl: 'https://example.com',
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 1)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FestivalCard(
              festival: liveFestival,
              sortedFestivals: [liveFestival],
              isSelected: false,
              onTap: () {},
              onInfoTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('shows COMING SOON badge for an upcoming festival', (
      tester,
    ) async {
      final upcomingFestival = Festival(
        id: 'upcoming-2099',
        name: 'Future Festival',
        dataBaseUrl: 'https://example.com',
        startDate: DateTime(2099, 1, 1),
        endDate: DateTime(2099, 1, 7),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FestivalCard(
              festival: upcomingFestival,
              sortedFestivals: [upcomingFestival],
              isSelected: false,
              onTap: () {},
              onInfoTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('COMING SOON'), findsOneWidget);
    });

    testWidgets('does not show date row when festival has no dates', (
      tester,
    ) async {
      final noDatesFestival = Festival(
        id: 'no-dates',
        name: 'No Dates Festival',
        dataBaseUrl: 'https://example.com',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FestivalCard(
              festival: noDatesFestival,
              sortedFestivals: [noDatesFestival],
              isSelected: false,
              onTap: () {},
              onInfoTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.calendar_today), findsNothing);
    });

    testWidgets('does not show location row when festival has no location', (
      tester,
    ) async {
      final noLocationFestival = Festival(
        id: 'no-location',
        name: 'No Location Festival',
        dataBaseUrl: 'https://example.com',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FestivalCard(
              festival: noLocationFestival,
              sortedFestivals: [noLocationFestival],
              isSelected: false,
              onTap: () {},
              onInfoTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.location_on), findsNothing);
    });

    testWidgets(
      'does not show beverage type chips when no types are available',
      (tester) async {
        final noTypesFestival = Festival(
          id: 'no-types',
          name: 'No Types Festival',
          dataBaseUrl: 'https://example.com',
          availableBeverageTypes: const [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FestivalCard(
                festival: noTypesFestival,
                sortedFestivals: [noTypesFestival],
                isSelected: false,
                onTap: () {},
                onInfoTap: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('beverage_chips_wrap')), findsNothing);
      },
    );

    testWidgets('shows at most 5 beverage type chips when more are available', (
      tester,
    ) async {
      final manyTypesFestival = Festival(
        id: 'many-types',
        name: 'Many Types Festival',
        dataBaseUrl: 'https://example.com',
        availableBeverageTypes: const [
          'beer',
          'cider',
          'perry',
          'mead',
          'wine',
          'low-no',
          'international-beer',
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FestivalCard(
              festival: manyTypesFestival,
              sortedFestivals: [manyTypesFestival],
              isSelected: false,
              onTap: () {},
              onInfoTap: () {},
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('beverage_chips_wrap')),
          matching: find.byType(Text),
        ),
        findsNWidgets(5),
      );
    });

    testWidgets('info button has correct semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Festival information' &&
              widget.properties.button == true,
        ),
        findsOneWidget,
      );
    });
  });

  group('SettingsSheet', () {
    late BeerProvider provider;
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [],
          defaultFestivalId: '',
          version: '1.0.0',
          baseUrl: 'https://data.cambeerfestival.app',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );

      await provider.initialize();
    });

    Widget buildTestWidget({ThemeData? theme}) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: SettingsSheet(provider: provider),
          ),
        ),
      );
    }

    tearDown(() => provider.dispose());

    testWidgets('displays settings title and theme option', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
    });

    testWidgets('shows system mode by default', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('System mode'), findsOneWidget);
      expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
    });

    testWidgets('uses high-contrast drag handle color in light theme', (
      tester,
    ) async {
      final lightTheme = buildAppTheme(Brightness.light);
      await tester.pumpWidget(buildTestWidget(theme: lightTheme));

      final handleContainer = tester.widget<Container>(
        find.byKey(const Key('settings_sheet_drag_handle')),
      );
      final decoration = handleContainer.decoration! as BoxDecoration;

      expect(decoration.color, lightTheme.colorScheme.onSurfaceVariant);
    });

    testWidgets('shows Light label and icon when theme is light', (
      tester,
    ) async {
      provider.setThemeMode(ThemeMode.light);
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Light mode'), findsOneWidget);
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
    });

    testWidgets('shows Dark label and icon when theme is dark', (tester) async {
      provider.setThemeMode(ThemeMode.dark);
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Dark mode'), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('theme card semantics label includes current theme mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.startsWith('Change theme, currently') ??
                  false),
        ),
        findsOneWidget,
      );
    });
  });

  group('ThemeSelectorSheet', () {
    late BeerProvider provider;
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [],
          defaultFestivalId: '',
          version: '1.0.0',
          baseUrl: 'https://data.cambeerfestival.app',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );

      await provider.initialize();
    });

    Widget buildTestWidget({ThemeData? theme}) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: ThemeSelectorSheet(provider: provider),
          ),
        ),
      );
    }

    tearDown(() => provider.dispose());

    testWidgets('displays all three theme options', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('shows correct icons for each theme', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('changes theme when light selected', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(provider.themeMode, ThemeMode.light);
    });

    testWidgets('changes theme when dark selected', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(provider.themeMode, ThemeMode.dark);
    });

    testWidgets('uses high-contrast drag handle color in light theme', (
      tester,
    ) async {
      final lightTheme = buildAppTheme(Brightness.light);
      await tester.pumpWidget(buildTestWidget(theme: lightTheme));

      final handleContainer = tester.widget<Container>(
        find.byKey(const Key('theme_selector_sheet_drag_handle')),
      );
      final decoration = handleContainer.decoration! as BoxDecoration;

      expect(decoration.color, lightTheme.colorScheme.onSurfaceVariant);
    });

    testWidgets('shows subtitles for all three theme options', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Follow device settings'), findsOneWidget);
      expect(find.text('Always use light theme'), findsOneWidget);
      expect(find.text('Always use dark theme'), findsOneWidget);
    });

    testWidgets('changes theme to system when system option is tapped', (
      tester,
    ) async {
      provider.setThemeMode(ThemeMode.light);
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();

      expect(provider.themeMode, ThemeMode.system);
    });
  });
}
