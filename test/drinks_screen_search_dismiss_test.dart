import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

/// Covers the two paths that dismiss the search bar. Both used to call
/// `provider.setSearchQuery('')` from inside a `setState` closure, firing
/// `notifyListeners()` while the element was being marked dirty (issue #526).
/// These tests assert the user-visible outcome of each path — the bar closes
/// and the full list comes back — so the behaviour is pinned regardless of how
/// the rebuild is scheduled.
void main() {
  group('DrinksScreen search dismissal', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

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
    ];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

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
      when(
        mockFestivalRepository.getFestivals(),
      ).thenAnswer((_) async => festivalsResponse);
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => testDrinks);

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

    Widget createTestWidget() {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: const MaterialApp(home: DrinksScreen(festivalId: 'cbf2025')),
      );
    }

    Future<void> tapBySemanticsLabel(WidgetTester tester, String label) async {
      final semantics = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
      semantics.dispose();
    }

    /// Opens the search bar and applies [query], waiting out the 300ms debounce
    /// so the provider has actually filtered the list.
    Future<void> searchFor(WidgetTester tester, String query) async {
      await tapBySemanticsLabel(tester, 'Search drinks');
      await tester.enterText(find.byType(TextField).first, query);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    testWidgets('clear button closes the search bar and restores the list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await searchFor(tester, 'Alpha');
      // The provider normalises the query to lower case.
      expect(provider.searchQuery, 'alpha');
      expect(find.text('Alpha IPA'), findsOneWidget);
      expect(find.text('Beta Bitter'), findsNothing);

      await tapBySemanticsLabel(tester, 'Clear search');

      // The search field is gone and the unfiltered list is back on screen.
      expect(find.byType(TextField), findsNothing);
      expect(provider.searchQuery, '');
      expect(find.text('Alpha IPA'), findsOneWidget);
      expect(find.text('Beta Bitter'), findsOneWidget);
    });

    testWidgets('collapsing via the search button clears the query', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await searchFor(tester, 'Alpha');
      expect(find.text('Beta Bitter'), findsNothing);

      // The search button relabels itself while the bar is open.
      await tapBySemanticsLabel(tester, 'Close search');

      expect(find.byType(TextField), findsNothing);
      expect(provider.searchQuery, '');
      expect(find.text('Alpha IPA'), findsOneWidget);
      expect(find.text('Beta Bitter'), findsOneWidget);
    });

    testWidgets('expanding the search bar leaves an existing query intact', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // A query set from elsewhere (e.g. a deep link) survives opening the bar:
      // only collapsing clears it.
      provider.setSearchQuery('Alpha');
      await tester.pumpAndSettle();

      await tapBySemanticsLabel(tester, 'Search drinks');

      expect(find.byType(TextField), findsOneWidget);
      expect(provider.searchQuery, 'alpha');
      expect(find.text('Alpha IPA'), findsOneWidget);
      expect(find.text('Beta Bitter'), findsNothing);
    });
  });
}
