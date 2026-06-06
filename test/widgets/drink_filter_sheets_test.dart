import 'package:cambridge_beer_festival/domain/models/models.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/widgets/drink_filter_sheets.dart';
import 'package:cambridge_beer_festival/widgets/festival_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_test.mocks.dart';

void main() {
  group('drink filter sheets', () {
    late BeerProvider provider;

    Drink beer(
      String id,
      String name,
      String style, {
      Map<String, int> allergens = const {},
      bool? isVegan,
    }) => Drink(
      product: Product(
        id: id,
        name: name,
        abv: 5.0,
        category: 'beer',
        dispense: 'cask',
        style: style,
        allergens: allergens,
        isVegan: isVegan,
      ),
      producer: const Producer(
        id: 'b1',
        name: 'Test Brewery',
        location: 'Cambridge',
        products: [],
      ),
      festivalId: 'cbf2025',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final mockDrinkRepository = MockDrinkRepository();
      final mockFestivalRepository = MockFestivalRepository();
      final mockAnalyticsService = MockAnalyticsService();

      const testFestival = Festival(
        id: 'cbf2025',
        name: 'Cambridge Beer Festival 2025',
        dataBaseUrl: 'https://test.example.com/cbf2025',
      );
      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: const [testFestival],
          defaultFestivalId: 'cbf2025',
          baseUrl: 'https://example.com',
          version: '1.0.0',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any)).thenAnswer(
        (_) async => [
          beer(
            'd1',
            'Zeta IPA',
            'IPA',
            allergens: {'gluten': 1},
            isVegan: true,
          ),
          beer('d2', 'Alpha Bitter', 'Bitter'),
        ],
      );

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
      await provider.loadDrinks();
    });

    tearDown(() => provider.dispose());

    // Pumps a sheet directly as the body — for render-only assertions.
    Widget directHost(Widget sheet) {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(home: Scaffold(body: sheet)),
      );
    }

    // Pumps a screen with launcher buttons that open each sheet via the public
    // show* helpers, so Navigator.pop closes the sheet (not the whole app) and
    // the helpers themselves are exercised.
    Widget launcherHost() {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showCategoryFilter(context),
                    child: const Text('open-category'),
                  ),
                  TextButton(
                    onPressed: () => showStyleFilter(context),
                    child: const Text('open-style'),
                  ),
                  TextButton(
                    onPressed: () => showSortOptions(context),
                    child: const Text('open-sort'),
                  ),
                  TextButton(
                    onPressed: () => showVisibilityFilter(context),
                    child: const Text('open-visibility'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('CategoryFilterSheet lists categories with counts', (
        tester,
      ) async {
        await tester.pumpWidget(
          directHost(CategoryFilterSheet(provider: provider)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Filter by Category'), findsOneWidget);
        expect(find.text('All (2)'), findsOneWidget);
        expect(find.textContaining('Beer'), findsOneWidget);
      });

      testWidgets('SortOptionsSheet lists every sort option label', (
        tester,
      ) async {
        await tester.pumpWidget(
          directHost(SortOptionsSheet(provider: provider)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sort By'), findsOneWidget);
        expect(find.text('Name (A-Z)'), findsOneWidget);
        expect(find.text('ABV (High to Low)'), findsOneWidget);
      });

      testWidgets('StyleFilterSheet shows styles in case-insensitive order', (
        tester,
      ) async {
        await tester.pumpWidget(directHost(const StyleFilterSheet()));
        await tester.pumpAndSettle();

        expect(find.text('Filter by Style'), findsOneWidget);

        // Provider supplies the sorted order; Bitter precedes IPA on screen.
        final bitterY = tester.getTopLeft(find.text('Bitter (1)')).dy;
        final ipaY = tester.getTopLeft(find.text('IPA (1)')).dy;
        expect(bitterY, lessThan(ipaY));
      });
    });

    group('via show* helpers', () {
      testWidgets(
        'showCategoryFilter: selecting a category sets it and closes',
        (tester) async {
          await tester.pumpWidget(launcherHost());
          await tester.tap(find.text('open-category'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Beer (2)'));
          await tester.pumpAndSettle();

          expect(provider.selectedCategory, 'beer');
          expect(find.text('Filter by Category'), findsNothing);
        },
      );

      testWidgets('showCategoryFilter: selecting All clears the category', (
        tester,
      ) async {
        provider.setCategory('beer');
        await tester.pumpWidget(launcherHost());
        await tester.tap(find.text('open-category'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('All (2)'));
        await tester.pumpAndSettle();

        expect(provider.selectedCategory, isNull);
      });

      testWidgets('showSortOptions: selecting a sort applies it and closes', (
        tester,
      ) async {
        await tester.pumpWidget(launcherHost());
        await tester.tap(find.text('open-sort'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('ABV (High to Low)'));
        await tester.pumpAndSettle();

        expect(provider.currentSort, DrinkSort.abvHigh);
        expect(find.text('Sort By'), findsNothing);
      });

      testWidgets('showStyleFilter: toggling a style then clearing', (
        tester,
      ) async {
        await tester.pumpWidget(launcherHost());
        await tester.tap(find.text('open-style'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('IPA (1)'));
        await tester.pumpAndSettle();
        expect(provider.selectedStyles, contains('IPA'));

        // Clear button appears once a style is selected.
        await tester.tap(find.widgetWithText(TextButton, 'Clear'));
        await tester.pumpAndSettle();
        expect(provider.selectedStyles, isEmpty);
      });

      testWidgets('showVisibilityFilter: toggles a visibility filter', (
        tester,
      ) async {
        await tester.pumpWidget(launcherHost());
        await tester.tap(find.text('open-visibility'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(CheckboxListTile, 'Available only'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Not tasted'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Vegan only'));
        await tester.pumpAndSettle();

        expect(
          provider.visibilityFilters,
          containsAll([
            DrinkVisibilityFilter.availableOnly,
            DrinkVisibilityFilter.notTasted,
            DrinkVisibilityFilter.veganOnly,
          ]),
        );
      });

      testWidgets(
        'showVisibilityFilter: renders and toggles the allergen tiles',
        (tester) async {
          await tester.pumpWidget(launcherHost());
          await tester.tap(find.text('open-visibility'));
          await tester.pumpAndSettle();

          // d1 carries a gluten allergen, so the allergen-free section appears.
          expect(find.text('Allergen-free'), findsOneWidget);

          await tester.tap(find.widgetWithText(CheckboxListTile, 'Gluten'));
          await tester.pumpAndSettle();

          expect(provider.excludedAllergens, contains('gluten'));
        },
      );

      testWidgets('showVisibilityFilter: clear resets active filters', (
        tester,
      ) async {
        await provider.setVisibilityFilter(
          DrinkVisibilityFilter.availableOnly,
          active: true,
        );
        await tester.pumpWidget(launcherHost());
        await tester.tap(find.text('open-visibility'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Clear'));
        await tester.pumpAndSettle();

        expect(provider.visibilityFilters, isEmpty);
        expect(provider.excludedAllergens, isEmpty);
      });
    });

    testWidgets('FestivalBanner is hidden when the festival has no dates or '
        'location', (tester) async {
      // The test festival has neither dates nor a location.
      await tester.pumpWidget(
        directHost(FestivalBanner(provider: provider, festivalId: 'cbf2025')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InkWell), findsNothing);
    });
  });
}
