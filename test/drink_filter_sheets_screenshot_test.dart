// Golden coverage for the four filter sheets in
// lib/widgets/drink_filter_sheets.dart (#508).
//
// Before this file, every test for these sheets asserted presence, ordering by
// `dy`, or semantics — nothing asserted horizontal position, size, spacing or
// colour. PR #506 shipped centre-aligned style-category headers past 1313
// green tests because of exactly that gap; it was caught only by eye in a
// browser. These baselines close it.
//
// Each sheet is pumped as the Scaffold body (the `directHost` shape used by
// drink_filter_sheets_test.dart) rather than through showModalBottomSheet:
// the child layout is identical either way, and there is no route animation
// or scrim to settle. The real `buildAppTheme` is used, and every baseline is
// captured in both brightnesses — buildAppTheme branches on brightness, so
// dark is where contrast regressions hide.
import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/domain/models/models.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/widgets/drink_filter_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('Drink filter sheet screenshot tests', () {
    late BeerProvider provider;

    Drink drink(
      String id,
      String name,
      String? style, {
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
      // Two categories with styles so StyleFilterSheet groups (headers shown),
      // and two distinct allergens so VisibilityFilterSheet renders its
      // allergen section.
      when(mockDrinkRepository.getDrinks(any)).thenAnswer(
        (_) async => [
          drink(
            'd1',
            'Zeta IPA',
            'IPA',
            allergens: {'gluten': 1},
            isVegan: true,
          ),
          drink('d2', 'Alpha Bitter', 'Bitter'),
          drink('d3', 'Midnight Stout', 'Stout', allergens: {'nuts': 1}),
          drink('d4', 'Crisp Cider', 'Dry', category: 'cider'),
          drink('d5', 'Orchard Gold', 'Medium', category: 'cider'),
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

    Future<void> pumpSheet(
      WidgetTester tester,
      Widget sheet,
      Brightness brightness,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: buildAppTheme(brightness),
            home: Scaffold(body: sheet),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const brightnesses = <String, Brightness>{
      'light': Brightness.light,
      'dark': Brightness.dark,
    };

    for (final entry in brightnesses.entries) {
      final themeName = entry.key;
      final brightness = entry.value;

      testWidgets('CategoryFilterSheet with no selection - $themeName theme', (
        tester,
      ) async {
        await pumpSheet(tester, const CategoryFilterSheet(), brightness);

        await expectLater(
          find.byType(CategoryFilterSheet),
          matchesGoldenFile('goldens/category_filter_sheet_$themeName.png'),
        );
      });

      testWidgets('CategoryFilterSheet with multiple categories selected - '
          '$themeName theme', (tester) async {
        // Two selections: "All" unticks, both rows tick, and the Clear
        // button appears opposite the title.
        provider
          ..toggleCategory('beer')
          ..toggleCategory('cider');

        await pumpSheet(tester, const CategoryFilterSheet(), brightness);

        await expectLater(
          find.byType(CategoryFilterSheet),
          matchesGoldenFile(
            'goldens/category_filter_sheet_selected_$themeName.png',
          ),
        );
      });

      testWidgets('StyleFilterSheet grouped by category - $themeName theme', (
        tester,
      ) async {
        // No category filter, so both beer and cider styles are in scope and
        // the category headers render. This is the #506 regression guard: the
        // headers are the only children narrower than the sheet, so a missing
        // CrossAxisAlignment.start centres them.
        provider.toggleStyle('IPA');

        await pumpSheet(tester, const StyleFilterSheet(), brightness);

        await expectLater(
          find.byType(StyleFilterSheet),
          matchesGoldenFile(
            'goldens/style_filter_sheet_grouped_$themeName.png',
          ),
        );
      });

      testWidgets(
        'StyleFilterSheet flat with one category - $themeName theme',
        (tester) async {
          // A single category in scope collapses to one group, which renders
          // flat with no header — a lone header is noise.
          provider.toggleCategory('beer');

          await pumpSheet(tester, const StyleFilterSheet(), brightness);

          await expectLater(
            find.byType(StyleFilterSheet),
            matchesGoldenFile('goldens/style_filter_sheet_flat_$themeName.png'),
          );
        },
      );

      testWidgets(
        'VisibilityFilterSheet with allergen section - $themeName theme',
        (tester) async {
          // One visibility filter and one allergen exclusion active, so the
          // divider, the allergen section, a ticked checkbox and the Clear
          // button are all in the baseline.
          await provider.setVisibilityFilter(
            DrinkVisibilityFilter.availableOnly,
            active: true,
          );
          await provider.setAllergenFilter('gluten', active: true);

          await pumpSheet(tester, const VisibilityFilterSheet(), brightness);

          await expectLater(
            find.byType(VisibilityFilterSheet),
            matchesGoldenFile('goldens/visibility_filter_sheet_$themeName.png'),
          );
        },
      );

      testWidgets('SortOptionsSheet - $themeName theme', (tester) async {
        await pumpSheet(tester, const SortOptionsSheet(), brightness);

        await expectLater(
          find.byType(SortOptionsSheet),
          matchesGoldenFile('goldens/sort_options_sheet_$themeName.png'),
        );
      });
    }
  });
}
