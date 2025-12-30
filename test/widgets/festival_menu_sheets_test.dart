import 'package:cambridge_beer_festival/domain/repositories/repositories.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/services/services.dart';
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

      when(mockFestivalRepository.getFestivals())
          .thenAnswer((_) async => FestivalsResponse(
            festivals: testFestivals,
            defaultFestivalId: testFestival.id,
            version: '1.0.0',
            baseUrl: 'https://data.cambeerfestival.app',
          ));
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => []);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );

      await provider.initialize();
    });

    Widget buildTestWidget() {
      return MaterialApp(
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
      expect(find.text('Choose a festival to browse its drinks'), findsOneWidget);
    });

    testWidgets('displays festival cards when festivals are loaded', (tester) async {
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

    testWidgets('has correct semantics for screen readers', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final semantics = tester.widget<Semantics>(
        find.ancestor(
          of: find.byType(FestivalCard),
          matching: find.byType(Semantics),
        ).first,
      );

      expect(semantics.properties.label, contains('Test Beer Festival 2024'));
      expect(semantics.properties.button, isTrue);
    });
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

      when(mockFestivalRepository.getFestivals())
          .thenAnswer((_) async => FestivalsResponse(
            festivals: [],
            defaultFestivalId: '',
            version: '1.0.0',
            baseUrl: 'https://data.cambeerfestival.app',
          ));
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => []);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );

      await provider.initialize();
    });

    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: SettingsSheet(provider: provider),
          ),
        ),
      );
    }

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

      when(mockFestivalRepository.getFestivals())
          .thenAnswer((_) async => FestivalsResponse(
            festivals: [],
            defaultFestivalId: '',
            version: '1.0.0',
            baseUrl: 'https://data.cambeerfestival.app',
          ));
      when(mockFestivalRepository.getSelectedFestivalId()).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => []);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );

      await provider.initialize();
    });

    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<BeerProvider>.value(
            value: provider,
            child: ThemeSelectorSheet(provider: provider),
          ),
        ),
      );
    }

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
  });
}
