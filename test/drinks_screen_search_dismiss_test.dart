import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

    testWidgets('search bar hint names the fields search reaches', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tapBySemanticsLabel(tester, 'Search drinks');

      // Pinned so this and SearchMatchService._searchableFields cannot drift
      // apart silently: a field added there should prompt a hint edit here.
      expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .decoration
            ?.hintText,
        'Search drinks, styles, notes...',
      );
    });

    testWidgets('search bar hint is not ellipsised on a 375px screen', (
      WidgetTester tester,
    ) async {
      // The hint is the only place the note search is discoverable, so a hint
      // that truncates defeats its own purpose. 375px is the narrowest phone
      // still worth supporting; the field's prefix icon, clear button and
      // padding leave the hint 239px to render in.
      //
      // The theme matters: the app renders the hint in NunitoSans via
      // buildAppTheme, whereas a bare MaterialApp falls back to a font
      // flutter_test cannot resolve and draws every glyph as a fixed-width
      // placeholder box. Measuring against that would be measuring nothing.
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const DrinksScreen(festivalId: 'cbf2025'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapBySemanticsLabel(tester, 'Search drinks');

      final hint = tester.renderObject<RenderParagraph>(
        find.text('Search drinks, styles, notes...').first,
      );
      expect(
        hint.didExceedMaxLines,
        isFalse,
        reason:
            'The hint renders in ${hint.size.width}px but needs '
            '${hint.getMaxIntrinsicWidth(double.infinity)}px, so it is being '
            'ellipsised. Shorten it rather than widening the field.',
      );
    });
  });
}
