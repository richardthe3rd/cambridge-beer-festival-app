import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('DrinksScreen Style Filter', () {
    late MockBeerApiService mockApiService;
    late MockFestivalService mockFestivalService;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    // Create test drinks with different styles
    final testDrinks = [
      Drink(
        product: const Product(
          id: 'drink1',
          name: 'Alpha IPA',
          abv: 5.5,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        ),
        producer: const Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'cbf2025',
      ),
      Drink(
        product: const Product(
          id: 'drink2',
          name: 'Beta Bitter',
          abv: 4.2,
          category: 'beer',
          dispense: 'cask',
          style: 'Bitter',
        ),
        producer: const Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'cbf2025',
      ),
      Drink(
        product: const Product(
          id: 'drink3',
          name: 'Gamma Stout',
          abv: 6.0,
          category: 'beer',
          dispense: 'keg',
          style: 'Stout',
        ),
        producer: const Producer(
          id: 'brewery2',
          name: 'Another Brewery',
          location: 'London',
          products: [],
        ),
        festivalId: 'cbf2025',
      ),
    ];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockApiService = MockBeerApiService();
      mockFestivalService = MockFestivalService();
      mockAnalyticsService = MockAnalyticsService();

      // Mock fetchFestivals to return a test festival
      const testFestival = Festival(
        id: 'cbf2025',
        name: 'Cambridge Beer Festival 2025',
        dataBaseUrl: 'https://test.example.com/cbf2025',
      );
      final festivalsResponse = FestivalsResponse(
        festivals: [testFestival],
        defaultFestivalId: 'cbf2025',
        baseUrl: 'https://example.com',
        version: '1.0.0',
      );
      when(mockFestivalService.fetchFestivals())
          .thenAnswer((_) async => festivalsResponse);

      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => testDrinks);

      provider = BeerProvider(
        apiService: mockApiService,
        festivalService: mockFestivalService,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
      await provider.loadDrinks();
    });

    tearDown(() {
      provider.dispose();
    });

    Widget createTestWidget() {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: DrinksScreen(festivalId: 'cbf2025'),
        ),
      );
    }

    testWidgets('style filter button shows when styles are available',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show the style filter button
      expect(find.text('Style'), findsOneWidget);
    });

    testWidgets('style filter sheet opens when style button is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap the style filter button
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();

      // Should show the style filter sheet
      expect(find.text('Filter by Style'), findsOneWidget);
      expect(find.text('IPA (1)'), findsOneWidget);
      expect(find.text('Bitter (1)'), findsOneWidget);
      expect(find.text('Stout (1)'), findsOneWidget);
    });

    testWidgets('checkbox updates immediately when style is toggled',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open style filter sheet
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();

      // Verify IPA checkbox is initially unchecked
      final ipaCheckbox = find.widgetWithText(CheckboxListTile, 'IPA (1)');
      expect(ipaCheckbox, findsOneWidget);
      
      CheckboxListTile checkboxWidget = tester.widget(ipaCheckbox);
      expect(checkboxWidget.value, false);

      // Tap the IPA checkbox
      await tester.tap(ipaCheckbox);
      await tester.pumpAndSettle();

      // Verify checkbox is now checked (this is the fix!)
      checkboxWidget = tester.widget(ipaCheckbox);
      expect(checkboxWidget.value, true);

      // Verify the provider state updated
      expect(provider.selectedStyles.contains('IPA'), true);
    });

    testWidgets('multiple styles can be selected with checkboxes updating',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open style filter sheet
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();

      // Select IPA
      await tester.tap(find.widgetWithText(CheckboxListTile, 'IPA (1)'));
      await tester.pumpAndSettle();

      // Verify IPA is checked
      CheckboxListTile ipaCheckbox = tester.widget(
        find.widgetWithText(CheckboxListTile, 'IPA (1)'),
      );
      expect(ipaCheckbox.value, true);

      // Select Bitter
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Bitter (1)'));
      await tester.pumpAndSettle();

      // Verify both are checked
      ipaCheckbox = tester.widget(
        find.widgetWithText(CheckboxListTile, 'IPA (1)'),
      );
      final bitterCheckbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Bitter (1)'),
      );
      expect(ipaCheckbox.value, true);
      expect(bitterCheckbox.value, true);

      // Verify provider state
      expect(provider.selectedStyles.contains('IPA'), true);
      expect(provider.selectedStyles.contains('Bitter'), true);
      expect(provider.selectedStyles.length, 2);
    });

    testWidgets('unchecking a style updates checkbox immediately',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open style filter sheet
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();

      // Select IPA
      final ipaCheckbox = find.widgetWithText(CheckboxListTile, 'IPA (1)');
      await tester.tap(ipaCheckbox);
      await tester.pumpAndSettle();

      // Verify it's checked
      CheckboxListTile checkboxWidget = tester.widget(ipaCheckbox);
      expect(checkboxWidget.value, true);

      // Uncheck IPA
      await tester.tap(ipaCheckbox);
      await tester.pumpAndSettle();

      // Verify checkbox is now unchecked
      checkboxWidget = tester.widget(ipaCheckbox);
      expect(checkboxWidget.value, false);

      // Verify provider state
      expect(provider.selectedStyles.contains('IPA'), false);
    });

    testWidgets('filter button shows selected style count',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially shows 'Style'
      expect(find.text('Style'), findsOneWidget);

      // Open style filter and select IPA
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'IPA (1)'));
      await tester.pumpAndSettle();

      // Close the sheet by tapping outside
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Button should show the selected style name
      // After closing, both the button and the checkbox list contain "IPA" text,
      // so we need to verify the provider state instead
      expect(provider.selectedStyles.contains('IPA'), true);
      expect(provider.selectedStyles.length, 1);

      // Open again and select another style
      await tester.tap(find.byIcon(Icons.style).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Bitter (1)'));
      await tester.pumpAndSettle();

      // Close the sheet
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Should have 2 styles selected
      expect(provider.selectedStyles.length, 2);
      expect(find.text('2 styles'), findsOneWidget);
    });

    testWidgets('clear button clears all selected styles and updates checkboxes',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open style filter and select multiple styles
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'IPA (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Bitter (1)'));
      await tester.pumpAndSettle();

      // Verify both are checked
      expect(provider.selectedStyles.length, 2);

      // Tap clear button
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // Verify all checkboxes are unchecked
      final ipaCheckbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'IPA (1)'),
      );
      final bitterCheckbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Bitter (1)'),
      );
      expect(ipaCheckbox.value, false);
      expect(bitterCheckbox.value, false);

      // Verify provider state
      expect(provider.selectedStyles.isEmpty, true);
    });

    testWidgets('styles remain in alphabetical order when selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open style filter
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();

      // Select Stout (alphabetically last)
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Stout (1)'));
      await tester.pumpAndSettle();

      // Find all CheckboxListTiles
      final checkboxes = find.byType(CheckboxListTile);
      expect(checkboxes, findsNWidgets(3));

      // Verify alphabetical order is maintained (Bitter, IPA, Stout)
      final firstCheckbox = tester.widget<CheckboxListTile>(checkboxes.at(0));
      final secondCheckbox = tester.widget<CheckboxListTile>(checkboxes.at(1));
      final thirdCheckbox = tester.widget<CheckboxListTile>(checkboxes.at(2));
      
      expect((firstCheckbox.title as Text).data, 'Bitter (1)');
      expect((secondCheckbox.title as Text).data, 'IPA (1)');
      expect((thirdCheckbox.title as Text).data, 'Stout (1)');
      
      // Verify Stout is selected but stays in alphabetical position
      expect(thirdCheckbox.value, true);
    });

    testWidgets('styles with non-ASCII characters sort correctly',
        (WidgetTester tester) async {
      // Override the test drinks to include non-ASCII characters
      final drinksWithAccents = [
        Drink(
          product: const Product(
            id: 'drink1',
            name: 'Rose Cider',
            abv: 5.0,
            category: 'cider',
            dispense: 'keg',
            style: 'Rose',
          ),
          producer: const Producer(
            id: 'cidery1',
            name: 'Test Cidery',
            location: 'France',
            products: [],
          ),
          festivalId: 'cbf2025',
        ),
        Drink(
          product: const Product(
            id: 'drink2',
            name: 'Rosé Cider',
            abv: 5.2,
            category: 'cider',
            dispense: 'keg',
            style: 'Rosé',
          ),
          producer: const Producer(
            id: 'cidery1',
            name: 'Test Cidery',
            location: 'France',
            products: [],
          ),
          festivalId: 'cbf2025',
        ),
        Drink(
          product: const Product(
            id: 'drink3',
            name: 'Cafe Stout',
            abv: 6.0,
            category: 'beer',
            dispense: 'cask',
            style: 'Cafe',
          ),
          producer: const Producer(
            id: 'brewery1',
            name: 'Test Brewery',
            location: 'UK',
            products: [],
          ),
          festivalId: 'cbf2025',
        ),
        Drink(
          product: const Product(
            id: 'drink4',
            name: 'Café Stout',
            abv: 6.2,
            category: 'beer',
            dispense: 'cask',
            style: 'Café',
          ),
          producer: const Producer(
            id: 'brewery1',
            name: 'Test Brewery',
            location: 'UK',
            products: [],
          ),
          festivalId: 'cbf2025',
        ),
      ];

      // Create new provider with accented test data
      final accentProvider = BeerProvider(
        apiService: mockApiService,
        festivalService: mockFestivalService,
        analyticsService: mockAnalyticsService,
      );
      
      when(mockApiService.fetchAllDrinks(any))
          .thenAnswer((_) async => drinksWithAccents);
      
      await accentProvider.initialize();
      await accentProvider.loadDrinks();

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: accentProvider,
          child: const MaterialApp(
            home: DrinksScreen(festivalId: 'cbf2025'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open style filter
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();

      // Find all CheckboxListTiles
      final checkboxes = find.byType(CheckboxListTile);
      expect(checkboxes, findsNWidgets(4));

      // Verify locale-aware alphabetical order:
      // Cafe, Café, Rose, Rosé
      final firstCheckbox = tester.widget<CheckboxListTile>(checkboxes.at(0));
      final secondCheckbox = tester.widget<CheckboxListTile>(checkboxes.at(1));
      final thirdCheckbox = tester.widget<CheckboxListTile>(checkboxes.at(2));
      final fourthCheckbox = tester.widget<CheckboxListTile>(checkboxes.at(3));
      
      expect((firstCheckbox.title as Text).data, 'Cafe (1)');
      expect((secondCheckbox.title as Text).data, 'Café (1)');
      expect((thirdCheckbox.title as Text).data, 'Rose (1)');
      expect((fourthCheckbox.title as Text).data, 'Rosé (1)');

      // Verify the accented characters display correctly (not garbled)
      expect((secondCheckbox.title as Text).data?.contains('é'), true,
        reason: 'Café should display the é character correctly');
      expect((fourthCheckbox.title as Text).data?.contains('é'), true,
        reason: 'Rosé should display the é character correctly');

      accentProvider.dispose();
    });
  });
}
