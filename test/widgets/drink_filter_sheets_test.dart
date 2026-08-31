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
      String category = 'beer',
      Map<String, int> allergens = const {},
      bool? isVegan,
    }) => Drink(
      product: Product(
        id: id,
        name: name,
        abv: 5.0,
        category: category,
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
          beer('d3', 'Crisp Cider', 'Dry', category: 'cider'),
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
    // textScale defaults to 1.0, so existing cases are unaffected; only the
    // #583 group below passes anything else.
    Widget directHost(Widget sheet, {double textScale = 1.0}) {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(body: sheet),
        ),
      );
    }

    // Pumps a screen with launcher buttons that open each sheet via the public
    // show* helpers, so Navigator.pop closes the sheet (not the whole app) and
    // the helpers themselves are exercised.
    Widget launcherHost({double textScale = 1.0}) {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
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
        await tester.pumpWidget(directHost(const CategoryFilterSheet()));
        await tester.pumpAndSettle();

        expect(find.text('Filter by Category'), findsOneWidget);
        expect(find.text('All (3)'), findsOneWidget);
        expect(find.text('Beer (2)'), findsOneWidget);
        expect(find.text('Cider (1)'), findsOneWidget);
      });

      testWidgets(
        'CategoryFilterSheet rows expose semantics label/value/selected',
        (tester) async {
          provider.toggleCategory('beer');
          await tester.pumpWidget(directHost(const CategoryFilterSheet()));
          await tester.pumpAndSettle();

          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == 'Filter by Beer, 2 drinks' &&
                  widget.properties.value == 'Selected' &&
                  widget.properties.selected == true,
            ),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == 'Filter by Cider, 1 drink' &&
                  widget.properties.value == 'Not selected' &&
                  widget.properties.selected == false,
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets('SortOptionsSheet lists every sort option label', (
        tester,
      ) async {
        await tester.pumpWidget(directHost(const SortOptionsSheet()));
        await tester.pumpAndSettle();

        expect(find.text('Sort By'), findsOneWidget);
        expect(find.text('Name (A-Z)'), findsOneWidget);
        expect(find.text('ABV (High to Low)'), findsOneWidget);
      });

      testWidgets(
        'SortOptionsSheet option rows are the same height as the other '
        'sheets (regression: #507)',
        (tester) async {
          await tester.pumpWidget(directHost(const SortOptionsSheet()));
          await tester.pumpAndSettle();

          final sortTiles = tester
              .widgetList<ListTile>(find.byType(ListTile))
              .toList();
          expect(sortTiles, isNotEmpty);
          for (final tile in sortTiles) {
            expect(
              tile.dense,
              isTrue,
              reason:
                  'Sort options must be dense to match the category, style, '
                  'and visibility sheets.',
            );
          }

          // The user-visible symptom was row pitch, not the flag: measure the
          // rendered height and compare it against a sheet that was always
          // dense, so this stays honest if Material changes its metrics.
          final sortRowHeight = tester
              .getSize(find.widgetWithText(ListTile, 'Name (A-Z)'))
              .height;

          await tester.pumpWidget(directHost(const CategoryFilterSheet()));
          await tester.pumpAndSettle();

          final categoryRowHeight = tester
              .getSize(find.widgetWithText(CheckboxListTile, 'Beer (2)'))
              .height;

          expect(sortRowHeight, categoryRowHeight);
        },
      );

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

      testWidgets('StyleFilterSheet style rows announce a singular drink '
          'count grammatically', (tester) async {
        await tester.pumpWidget(directHost(const StyleFilterSheet()));
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Filter by IPA, 1 drink' &&
                widget.properties.value == 'Not selected',
          ),
          findsOneWidget,
        );
        // The ungrammatical form must not reach a screen reader.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Filter by IPA, 1 drinks',
          ),
          findsNothing,
        );
      });

      testWidgets(
        'StyleFilterSheet renders a category header per group when no '
        'category is selected',
        (tester) async {
          // No category selected: 2 categories are in scope (beer, cider),
          // so headers render.
          await tester.pumpWidget(directHost(const StyleFilterSheet()));
          await tester.pumpAndSettle();

          expect(find.text('Beer'), findsOneWidget);
          expect(find.text('Cider'), findsOneWidget);
          // The Cider header sits above the Dry row (its only style).
          final headerY = tester.getTopLeft(find.text('Cider')).dy;
          final dryY = tester.getTopLeft(find.text('Dry (1)')).dy;
          expect(headerY, lessThan(dryY));

          // A header is the only child narrower than the sheet, so it centres
          // unless the enclosing Column aligns to the start. Pin it to the
          // left: it must start well left of the middle, near its own rows.
          final sheetWidth = tester
              .getSize(find.byType(StyleFilterSheet))
              .width;
          final headerX = tester.getTopLeft(find.text('Cider')).dx;
          expect(
            headerX,
            lessThan(sheetWidth / 4),
            reason: 'category header should be left-aligned, not centred',
          );
        },
      );

      testWidgets('StyleFilterSheet renders flat with no header when only one '
          'category is in scope', (tester) async {
        provider.toggleCategory('beer');
        await tester.pumpWidget(directHost(const StyleFilterSheet()));
        await tester.pumpAndSettle();

        expect(find.text('Beer'), findsNothing);
        expect(find.text('Bitter (1)'), findsOneWidget);
        expect(find.text('IPA (1)'), findsOneWidget);
      });

      testWidgets(
        'StyleFilterSheet category headers are exposed as semantics headers',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(directHost(const StyleFilterSheet()));
            await tester.pumpAndSettle();

            final headerNode = tester.getSemantics(find.text('Cider'));
            expect(
              headerNode.flagsCollection.isHeader,
              isTrue,
              reason: 'category header should carry the isHeader flag',
            );
          } finally {
            handle.dispose();
          }
        },
      );
    });

    group('via show* helpers', () {
      testWidgets(
        'showCategoryFilter: toggling a category selects it without closing '
        'the sheet',
        (tester) async {
          await tester.pumpWidget(launcherHost());
          await tester.tap(find.text('open-category'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Beer (2)'));
          await tester.pumpAndSettle();

          expect(provider.selectedCategories, {'beer'});
          // Unlike the old single-select radio sheet, the sheet stays open
          // so more categories can be toggled.
          expect(find.text('Filter by Category'), findsOneWidget);
        },
      );

      testWidgets('showCategoryFilter: toggling two categories reflects both '
          'selections', (tester) async {
        await tester.pumpWidget(launcherHost());
        await tester.tap(find.text('open-category'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Beer (2)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cider (1)'));
        await tester.pumpAndSettle();

        expect(provider.selectedCategories, {'beer', 'cider'});
        expect(find.text('Filter by Category'), findsOneWidget);

        final beerCheckbox = tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, 'Beer (2)'),
        );
        final ciderCheckbox = tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, 'Cider (1)'),
        );
        expect(beerCheckbox.value, isTrue);
        expect(ciderCheckbox.value, isTrue);
      });

      testWidgets('showCategoryFilter: selecting All clears the categories', (
        tester,
      ) async {
        provider.toggleCategory('beer');
        await tester.pumpWidget(launcherHost());
        await tester.tap(find.text('open-category'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('All (3)'));
        await tester.pumpAndSettle();

        expect(provider.selectedCategories, isEmpty);
      });

      testWidgets('showCategoryFilter: Clear button removes all selected '
          'categories', (tester) async {
        provider
          ..toggleCategory('beer')
          ..toggleCategory('cider');
        await tester.pumpWidget(launcherHost());
        await tester.tap(find.text('open-category'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Clear'));
        await tester.pumpAndSettle();

        expect(provider.selectedCategories, isEmpty);
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
        directHost(const FestivalBanner(festivalId: 'cbf2025')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InkWell), findsNothing);
    });

    group('headers at large text scales (#583)', () {
      // Each sheet header is a spaceBetween Row holding a titleLarge title and
      // the Clear button. Before #583 the title was unconstrained, so at an
      // accessibility text size it overflowed the row horizontally — by
      // 331-595px here — instead of wrapping. All three headers share that
      // shape, so all three are pinned: a fix applied to one must not be
      // dropped from the others.
      //
      // The Clear button has to be present for the squeeze to happen, so each
      // case activates a filter first.
      //
      // The assertion is on the title's laid-out width, not on the absence of
      // an exception: a wrapped title fits inside the sheet, an unconstrained
      // one is laid out at its full intrinsic width and spills past the edge.
      // That measures the fix directly, rather than depending on which of
      // several exceptions the framework happens to report first.

      // Opened through the show* helpers rather than pumped as a Scaffold
      // body: the modal route is the configuration users actually get, and the
      // one whose height constraints the sheets were built against.
      Future<void> openNarrow(WidgetTester tester, String launcher) async {
        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(launcherHost(textScale: 2.0));
        await tester.tap(find.text(launcher));
        await tester.pumpAndSettle();
      }

      void expectTitleFitsSheet(WidgetTester tester, Type sheet, String title) {
        final sheetWidth = tester
            .renderObject<RenderBox>(find.byType(sheet))
            .size
            .width;
        final titleWidth = tester
            .renderObject<RenderBox>(find.text(title))
            .size
            .width;

        expect(
          titleWidth,
          lessThanOrEqualTo(sheetWidth),
          reason:
              "'$title' is laid out wider than the sheet, so it is spilling "
              'past the Clear button instead of wrapping (#583).',
        );
        expect(find.widgetWithText(TextButton, 'Clear'), findsOneWidget);
      }

      testWidgets('CategoryFilterSheet header fits at 200%', (tester) async {
        provider.toggleCategory('beer');
        await openNarrow(tester, 'open-category');

        expectTitleFitsSheet(tester, CategoryFilterSheet, 'Filter by Category');
        expect(tester.takeException(), isNull);
      });

      testWidgets('StyleFilterSheet header fits at 200%', (tester) async {
        provider.toggleStyle('IPA');
        await openNarrow(tester, 'open-style');

        expectTitleFitsSheet(tester, StyleFilterSheet, 'Filter by Style');

        // Known residual, tracked in #623: this is the only sheet with pinned
        // chrome below the header (the animated selected-styles banner), and
        // with the title wrapped to two lines that chrome exceeds the sheet's
        // height * 0.7 cap by 8px. Taken deliberately so it does not fail the
        // run, but pinned to the vertical axis — a horizontal overflow here
        // would be the #583 regression this group exists to catch, and would
        // still fail.
        expect(tester.takeException().toString(), contains('on the bottom'));
      });

      testWidgets('VisibilityFilterSheet header fits at 200%', (tester) async {
        await provider.setVisibilityFilter(
          DrinkVisibilityFilter.availableOnly,
          active: true,
        );
        await openNarrow(tester, 'open-visibility');

        expectTitleFitsSheet(tester, VisibilityFilterSheet, 'View Filters');
        expect(tester.takeException(), isNull);
      });
    });
  });
}
