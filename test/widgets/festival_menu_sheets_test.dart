import 'package:cambridge_beer_festival_app/models/models.dart';
import 'package:cambridge_beer_festival_app/providers/beer_provider.dart';
import 'package:cambridge_beer_festival_app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'festival_menu_sheets_test.mocks.dart';

@GenerateMocks([BeerProvider])
void main() {
  group('FestivalSelectorSheet', () {
    late MockBeerProvider mockProvider;
    late Festival testFestival;
    late List<Festival> testFestivals;

    setUp(() {
      mockProvider = MockBeerProvider();
      testFestival = Festival(
        id: 'test-2024',
        name: 'Test Beer Festival 2024',
        dataUrl: 'https://example.com/test.json',
        startDate: DateTime(2024, 5, 20),
        endDate: DateTime(2024, 5, 25),
        location: 'Test Location',
        formattedDates: '20-25 May 2024',
        availableBeverageTypes: [BeverageType.beer, BeverageType.cider],
      );

      testFestivals = [testFestival];

      when(mockProvider.sortedFestivals).thenReturn(testFestivals);
      when(mockProvider.currentFestival).thenReturn(testFestival);
      when(mockProvider.isFestivalsLoading).thenReturn(false);
      when(mockProvider.festivalsError).thenReturn(null);
    });

    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<BeerProvider>.value(
            value: mockProvider,
            child: FestivalSelectorSheet(provider: mockProvider),
          ),
        ),
      );
    }

    testWidgets('displays loading indicator when festivals are loading', (tester) async {
      when(mockProvider.isFestivalsLoading).thenReturn(true);

      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Browse Festivals'), findsOneWidget);
    });

    testWidgets('displays error message when festivals fail to load', (tester) async {
      when(mockProvider.isFestivalsLoading).thenReturn(false);
      when(mockProvider.festivalsError).thenReturn('Failed to load');

      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Failed to load festivals'), findsOneWidget);
      expect(find.text('Failed to load'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('displays retry button when festivals fail to load', (tester) async {
      when(mockProvider.isFestivalsLoading).thenReturn(false);
      when(mockProvider.festivalsError).thenReturn('Failed to load');

      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      verify(mockProvider.loadFestivals()).called(1);
    });

    testWidgets('displays empty state when no festivals available', (tester) async {
      when(mockProvider.sortedFestivals).thenReturn([]);

      await tester.pumpWidget(buildTestWidget());

      expect(find.text('No festivals available'), findsOneWidget);
      expect(find.byIcon(Icons.festival_outlined), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
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

    testWidgets('calls setFestival and closes sheet when festival tapped', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byType(FestivalCard));
      await tester.pumpAndSettle();

      verify(mockProvider.setFestival(testFestival)).called(1);
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
        dataUrl: 'https://example.com/test.json',
        startDate: DateTime(2024, 5, 20),
        endDate: DateTime(2024, 5, 25),
        location: 'Test Location',
        formattedDates: '20-25 May 2024',
        availableBeverageTypes: [BeverageType.beer, BeverageType.cider],
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
      expect(find.text('20-25 May 2024'), findsOneWidget);
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

    testWidgets('limits beverage types to 5', (tester) async {
      testFestival = Festival(
        id: 'test-2024',
        name: 'Test Beer Festival 2024',
        dataUrl: 'https://example.com/test.json',
        startDate: DateTime(2024, 5, 20),
        endDate: DateTime(2024, 5, 25),
        availableBeverageTypes: [
          BeverageType.beer,
          BeverageType.cider,
          BeverageType.perry,
          BeverageType.mead,
          BeverageType.wine,
          BeverageType.internationalBeer,
        ],
      );

      testFestivals = [testFestival];

      await tester.pumpWidget(buildTestWidget());

      // Should only show 5 types
      final containerFinder = find.descendant(
        of: find.byType(Wrap),
        matching: find.byType(Container),
      );

      expect(containerFinder, findsNWidgets(5));
    });
  });

  group('SettingsSheet', () {
    late MockBeerProvider mockProvider;

    setUp(() {
      mockProvider = MockBeerProvider();
      when(mockProvider.themeMode).thenReturn(ThemeMode.system);
    });

    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<BeerProvider>.value(
            value: mockProvider,
            child: SettingsSheet(provider: mockProvider),
          ),
        ),
      );
    }

    testWidgets('displays current theme mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('System mode'), findsOneWidget);
    });

    testWidgets('shows correct icon for light mode', (tester) async {
      when(mockProvider.themeMode).thenReturn(ThemeMode.light);

      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.light_mode), findsOneWidget);
    });

    testWidgets('shows correct icon for dark mode', (tester) async {
      when(mockProvider.themeMode).thenReturn(ThemeMode.dark);

      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('shows correct icon for system mode', (tester) async {
      when(mockProvider.themeMode).thenReturn(ThemeMode.system);

      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
    });

    testWidgets('has correct semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(Card),
          matching: find.byType(Semantics),
        ).first,
      );

      expect(semantics.properties.label, contains('Change theme'));
      expect(semantics.properties.button, isTrue);
    });
  });

  group('ThemeSelectorSheet', () {
    late MockBeerProvider mockProvider;

    setUp(() {
      mockProvider = MockBeerProvider();
      when(mockProvider.themeMode).thenReturn(ThemeMode.system);
    });

    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<BeerProvider>.value(
            value: mockProvider,
            child: ThemeSelectorSheet(provider: mockProvider),
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

    testWidgets('calls setThemeMode when light selected', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      verify(mockProvider.setThemeMode(ThemeMode.light)).called(1);
    });

    testWidgets('calls setThemeMode when dark selected', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      verify(mockProvider.setThemeMode(ThemeMode.dark)).called(1);
    });

    testWidgets('calls setThemeMode when system selected', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();

      verify(mockProvider.setThemeMode(ThemeMode.system)).called(1);
    });
  });
}
