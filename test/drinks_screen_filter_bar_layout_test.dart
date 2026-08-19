// Layout regression guard for issue #579: at phone widths the category
// FilterButton lost its text label entirely once a filter was applied,
// rendering as two bare icons. The bottom control row is over-subscribed at
// 400 logical px — five controls, two of them fixed 48px squares — so the
// spacing in _BottomControls (lib/screens/drinks_screen.dart) is derived from
// a width budget rather than chosen by eye. This file pins that budget: if
// someone widens the padding, the gaps, the button padding, or the type
// scale, the labels start ellipsizing again and these tests say so.
//
// The assertion is "is this text ellipsized", not "is this text present":
// find.text() passes just as happily on a label clipped to zero width, which
// is exactly the bug that shipped.
import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/widgets/drinks_filter_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('Drinks screen filter bar layout', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    // Two categories and two styles so both the category and style
    // FilterButtons can be driven into their widest ('N categories' /
    // 'N styles') label state.
    const producer = Producer(
      id: 'brewery1',
      name: 'Cambridge Brewing Company',
      location: 'Cambridge, UK',
      yearFounded: 1990,
      products: [],
    );

    final drinks = <Drink>[
      Drink(
        product: const Product(
          id: 'drink1',
          name: 'Hoppy Heaven IPA',
          abv: 6.2,
          category: 'beer',
          style: 'IPA',
          dispense: 'cask',
        ),
        producer: producer,
        festivalId: 'cbf2025',
      ),
      Drink(
        product: const Product(
          id: 'drink2',
          name: 'Midnight Stout',
          abv: 4.8,
          category: 'beer',
          style: 'Stout',
          dispense: 'cask',
        ),
        producer: producer,
        festivalId: 'cbf2025',
      ),
      Drink(
        product: const Product(
          id: 'drink3',
          name: 'Orchard Gold',
          abv: 5.5,
          category: 'cider',
          style: 'Dry',
          dispense: 'keg',
        ),
        producer: producer,
        festivalId: 'cbf2025',
      ),
    ];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [DefaultFestivals.cambridge2025],
          defaultFestivalId: DefaultFestivals.cambridge2025.id,
          version: '1.0',
          baseUrl: 'https://data.cambeerfestival.app',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => drinks);

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

    /// Pumps DrinksScreen at [width] logical px inside a real GoRouter, as
    /// the screen reaches context.push/context.go (see validation-and-qa).
    Future<void> pumpAt(WidgetTester tester, double width) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/cbf2025',
        routes: [
          GoRoute(
            path: '/cbf2025',
            builder: (context, state) =>
                ChangeNotifierProvider<BeerProvider>.value(
                  value: provider,
                  child: const DrinksScreen(festivalId: 'cbf2025'),
                ),
          ),
          GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          theme: buildAppTheme(Brightness.light),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
    }

    /// How much of [label] is actually painted, as a fraction of the width the
    /// full string needs. 1.0 means it renders whole; anything less means the
    /// ellipsis has eaten into it. Scoped to the filter bar because drink
    /// cards render their own category/style chips with the same text.
    double renderedFraction(WidgetTester tester, String label) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(FilterButton),
          matching: find.text(label),
        ),
      );
      final needed = paragraph.getMaxIntrinsicWidth(double.infinity);
      return paragraph.size.width / needed;
    }

    testWidgets('category label survives at 400px with one category selected', (
      tester,
    ) async {
      provider.toggleCategory('beer');
      await pumpAt(tester, 400);

      expect(
        renderedFraction(tester, 'Beer'),
        greaterThanOrEqualTo(1.0),
        reason:
            'The active category label must render whole — #579 shipped it '
            'ellipsized to nothing, leaving two bare icons.',
      );
    });

    testWidgets('category label survives at 400px in its widest state', (
      tester,
    ) async {
      provider
        ..toggleCategory('beer')
        ..toggleCategory('cider');
      await pumpAt(tester, 400);

      expect(
        renderedFraction(tester, '2 categories'),
        greaterThanOrEqualTo(1.0),
        reason:
            "'N categories' is the widest label the category button can show; "
            'it is what the flex split in _BottomControls is sized for.',
      );
    });

    testWidgets('style label survives at 400px alongside an active category', (
      tester,
    ) async {
      provider
        ..toggleCategory('beer')
        ..toggleCategory('cider')
        ..toggleStyle('IPA')
        ..toggleStyle('Stout');
      await pumpAt(tester, 400);

      expect(
        renderedFraction(tester, '2 categories'),
        greaterThanOrEqualTo(1.0),
        reason: 'Both filter buttons must fit at once, not one at a time.',
      );
      expect(
        renderedFraction(tester, '2 styles'),
        greaterThanOrEqualTo(1.0),
        reason: 'Both filter buttons must fit at once, not one at a time.',
      );
    });

    testWidgets('inactive labels are unaffected by the active-state fix', (
      tester,
    ) async {
      await pumpAt(tester, 400);

      // 'Category' and 'Style' keep their leading glyph when no filter is
      // applied, and still fit.
      expect(renderedFraction(tester, 'Category'), greaterThanOrEqualTo(1.0));
      expect(renderedFraction(tester, 'Style'), greaterThanOrEqualTo(1.0));
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      expect(find.byIcon(Icons.style), findsOneWidget);
    });

    testWidgets('sort truncates by design and is not a regression', (
      tester,
    ) async {
      await pumpAt(tester, 400);

      // Documents the one label this row cannot fit: every DrinkSort label
      // ('Name (A-Z)', 'ABV (High to Low)') is wider than any share of a
      // 400px row, and sort is never active so it never gains the width the
      // dropped leading glyph frees. If this ever starts passing whole, the
      // budget above has changed and the comment in _BottomControls needs
      // revisiting. It also proves renderedFraction discriminates — the same
      // assertion that passes for the category label fails here.
      expect(renderedFraction(tester, 'Name (A-Z)'), lessThan(1.0));
    });

    testWidgets('every label renders whole on a wider phone', (tester) async {
      provider
        ..toggleCategory('beer')
        ..toggleCategory('cider')
        ..toggleStyle('IPA');
      await pumpAt(tester, 600);

      expect(
        renderedFraction(tester, '2 categories'),
        greaterThanOrEqualTo(1.0),
      );
      expect(renderedFraction(tester, 'IPA'), greaterThanOrEqualTo(1.0));
      expect(renderedFraction(tester, 'Name (A-Z)'), greaterThanOrEqualTo(1.0));
    });
  });
}
