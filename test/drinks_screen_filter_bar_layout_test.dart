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
import 'package:cambridge_beer_festival/widgets/drink_filter_sheets.dart';
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
    Future<void> pumpAt(
      WidgetTester tester,
      double width, {
      double textScale = 1.0,
    }) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/cbf2025',
        routes: [
          GoRoute(
            path: '/cbf2025',
            builder: (context, state) =>
                const DrinksScreen(festivalId: 'cbf2025'),
          ),
          GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        ],
      );
      // The provider sits above MaterialApp.router, as it does in main.dart
      // (lib/main.dart:102). Scoping it inside the route instead leaves the
      // filter sheets — pushed as modal routes, siblings of the screen —
      // unable to reach it, which is a property of the harness and not of the
      // app.
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(
            theme: buildAppTheme(Brightness.light),
            routerConfig: router,
            // The accessibility text size is a MediaQuery property, so it has
            // to be injected below the router rather than around it (#583).
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
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

    // ---- Large text scales (#583) ----
    //
    // WCAG 2.1 SC 1.4.4 (Resize text) asks that content and functionality
    // survive to 200%. Icon.applyTextScaling defaults to false, so the icons
    // in this row stay 18/16px while the labels grow — the whole width budget
    // documented in _BottomControls is spent on text, and it degrades faster
    // than the icons suggest.
    //
    // These assert the properties worth keeping rather than today's measured
    // percentages, which would make the file brittle against any type-scale
    // change: the active category label renders whole, nothing overflows,
    // truncated labels keep a readable prefix instead of collapsing to
    // nothing (the #579 failure mode), the filter state is still announced in
    // full, and the button still opens its sheet.

    for (final scale in <double>[1.3, 1.5, 2.0]) {
      testWidgets('active category label renders whole at ${scale}x text', (
        tester,
      ) async {
        provider.toggleCategory('beer');
        await pumpAt(tester, 400, textScale: scale);

        expect(
          renderedFraction(tester, 'Beer'),
          greaterThanOrEqualTo(1.0),
          reason:
              'One selected category is the common case, and dropping the '
              'leading glyph when active (#579) is what buys the room for it. '
              'If this fails, that headroom has been spent.',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the control row does not overflow at 200% text', (
      tester,
    ) async {
      provider
        ..toggleCategory('beer')
        ..toggleCategory('cider')
        ..toggleStyle('IPA')
        ..toggleStyle('Stout');
      await pumpAt(tester, 400, textScale: 2.0);

      // Every label in the row is Flexible with ellipsis overflow, so the
      // row should absorb the growth by truncating rather than throwing a
      // RenderFlex overflow. This is the assertion that would catch someone
      // making one of them unconstrained.
      expect(tester.takeException(), isNull);
      expect(find.byType(FilterButton), findsNWidgets(3));
    });

    testWidgets('truncated labels keep a readable prefix at 200% text', (
      tester,
    ) async {
      provider
        ..toggleCategory('beer')
        ..toggleCategory('cider')
        ..toggleStyle('IPA')
        ..toggleStyle('Stout');
      await pumpAt(tester, 400, textScale: 2.0);

      // A deliberately generous floor, not a pin of the current measurement
      // (~54%/56%). What it guards is the #579 failure mode — a label
      // ellipsized down to nothing, leaving a button with no text at all. If
      // this trips, the row has stopped degrading gracefully and the
      // judgement call in #583 needs making again.
      for (final label in <String>['2 categories', '2 styles']) {
        expect(
          renderedFraction(tester, label),
          greaterThan(0.4),
          reason:
              '\'$label\' should still show a readable prefix at 200%, not '
              'collapse to an ellipsis.',
        );
      }
    });

    testWidgets('the full filter state is still announced at 200% text', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        provider
          ..toggleCategory('beer')
          ..toggleCategory('cider')
          ..toggleStyle('IPA');
        await pumpAt(tester, 400, textScale: 2.0);

        // Visual truncation must not reach the screen reader: FilterButton
        // passes semanticLabel into a Semantics wrapper with
        // excludeSemantics: true, so the announcement is independent of how
        // much of the label is painted. This is the guarantee that makes the
        // truncation above tolerable rather than a loss of content.
        expect(
          find.bySemanticsLabel('Filter by category: Beer, Cider'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Filter by style: IPA'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('the category filter still opens its sheet at 200% text', (
      tester,
    ) async {
      provider
        ..toggleCategory('beer')
        ..toggleCategory('cider');
      await pumpAt(tester, 400, textScale: 2.0);

      // Functionality, not just content: SC 1.4.4 covers both. A button
      // squeezed to a sliver is no use if it can no longer be hit.
      await tester.tap(
        find.descendant(
          of: find.byType(FilterButton),
          matching: find.text('2 categories'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CategoryFilterSheet), findsOneWidget);
      expect(find.text('Filter by Category'), findsOneWidget);
    });

    testWidgets('the category sheet header does not overflow at 200% text', (
      tester,
    ) async {
      // The sheet a truncated filter button opens has to survive the same
      // text size the button does — reaching it is no use if its header then
      // overflows. Its title sits in a spaceBetween Row next to the Clear
      // button, so the title needs to be the part that yields.
      provider
        ..toggleCategory('beer')
        ..toggleCategory('cider');
      await pumpAt(tester, 400, textScale: 2.0);

      await tester.tap(
        find.descendant(
          of: find.byType(FilterButton),
          matching: find.text('2 categories'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clear'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
