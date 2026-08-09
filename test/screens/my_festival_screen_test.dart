import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/app_theme.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/utils/utils.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_test.mocks.dart';

/// A theme for golden tests that mirrors the app's seed colour but avoids
/// `google_fonts` (which fetches over the network and fails under test) — the
/// same approach the other screen screenshot tests use.
ThemeData _goldenTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF2B3170),
    brightness: brightness,
  ),
  useMaterial3: true,
  brightness: brightness,
);

void main() {
  group('MyFestivalScreen', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    const festival = Festival(
      id: 'cbf2025',
      name: 'Cambridge Beer Festival 2025',
      dataBaseUrl: 'https://example.com',
    );

    const producer = Producer(
      id: 'brewery1',
      name: 'Test Brewery',
      location: 'Cambridge, UK',
      products: [],
    );

    final wantToTryDrink = Drink(
      product: const Product(
        id: 'drink-a',
        name: 'Alpha Ale',
        abv: 4.2,
        category: 'beer',
        dispense: 'cask',
      ),
      producer: producer,
      festivalId: 'cbf2025',
    );

    final tastedOnlyDrink = Drink(
      product: const Product(
        id: 'drink-b',
        name: 'Beta Bitter',
        abv: 3.8,
        category: 'beer',
        dispense: 'cask',
      ),
      producer: producer,
      festivalId: 'cbf2025',
    );

    final bothDrink = Drink(
      product: const Product(
        id: 'drink-c',
        name: 'Gamma Gose',
        abv: 4.5,
        category: 'beer',
        dispense: 'keg',
      ),
      producer: producer,
      festivalId: 'cbf2025',
    );

    Future<void> setUpProvider() async {
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      when(mockFestivalRepository.getFestivals()).thenAnswer(
        (_) async => FestivalsResponse(
          festivals: [festival],
          defaultFestivalId: festival.id,
          version: '1.0',
          baseUrl: 'https://example.com',
        ),
      );
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
    }

    Widget createTestWidget({ThemeData? theme}) {
      final router = GoRouter(
        initialLocation: '/${festival.id}/favorites',
        routes: [
          GoRoute(
            path: '/:festivalId/favorites',
            builder: (context, state) =>
                ChangeNotifierProvider<BeerProvider>.value(
                  value: provider,
                  child: MyFestivalScreen(
                    festivalId: state.pathParameters['festivalId']!,
                  ),
                ),
          ),
          GoRoute(
            path: '/:festivalId/drink/:category/:id',
            builder: (context, state) =>
                const Scaffold(body: Text('Drink Detail')),
          ),
          // Stub root route so any context.go('/') calls don't throw.
          GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        ],
      );
      return MaterialApp.router(theme: theme, routerConfig: router);
    }

    testWidgets(
      'shows want-to-try drink under Want to Try and tasted drink under '
      'Tasted, and a both-flagged drink only under Tasted',
      (tester) async {
        await setUpProvider();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [wantToTryDrink, tastedOnlyDrink, bothDrink]);
        await provider.loadDrinks();

        final now = DateTime(2026, 6, 10, 18, 30);
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-a': UserDrinkState(
            wantToTry: true,
            createdAt: now,
            updatedAt: now,
          ),
          'drink-b': UserDrinkState(
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
          'drink-c': UserDrinkState(
            wantToTry: true,
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Want-to-try-only drink appears once, as a want-to-try row.
        expect(
          find.byKey(const ValueKey('want-to-try-drink-a')),
          findsOneWidget,
        );
        expect(find.text('Alpha Ale'), findsOneWidget);

        // Tasted-only drink appears once, as a tasted row.
        expect(find.byKey(const ValueKey('tasted-drink-b')), findsOneWidget);
        expect(find.text('Beta Bitter'), findsOneWidget);

        // Both-flagged drink appears ONLY under Tasted — Tasted takes
        // display priority per vision.md.
        expect(find.byKey(const ValueKey('tasted-drink-c')), findsOneWidget);
        expect(find.byKey(const ValueKey('want-to-try-drink-c')), findsNothing);
        expect(find.text('Gamma Gose'), findsOneWidget);
      },
    );

    testWidgets('placeholder row renders when catalogue entry is not loaded', (
      tester,
    ) async {
      await setUpProvider();
      // Catalogue does not include this drink — simulates not-yet-loaded.
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);
      await provider.loadDrinks();

      final now = DateTime.now();
      when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
        'unloaded-drink': UserDrinkState(
          wantToTry: true,
          createdAt: now,
          updatedAt: now,
        ),
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('placeholder-unloaded-drink')),
        findsOneWidget,
      );
      expect(find.text('unloaded-drink'), findsOneWidget);
      expect(find.text('Loading details…'), findsOneWidget);
    });

    testWidgets('shows empty state when both sections have no entries', (
      tester,
    ) async {
      await setUpProvider();
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);
      await provider.loadDrinks();
      when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Nothing in My Festival yet'), findsOneWidget);
    });

    group('user note in rows', () {
      testWidgets('renders the note under a want-to-try row', (tester) async {
        await setUpProvider();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [wantToTryDrink]);
        await provider.loadDrinks();

        final now = DateTime.now();
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-a': UserDrinkState(
            wantToTry: true,
            notes: 'Tom recommended this',
            createdAt: now,
            updatedAt: now,
          ),
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Want to Try rows now carry brewery + ABV recognition facts.
        expect(find.text('Test Brewery • 4.2%'), findsOneWidget);
        expect(find.text('Tom recommended this'), findsOneWidget);
      });

      testWidgets('renders the note under a tasted row', (tester) async {
        await setUpProvider();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [tastedOnlyDrink]);
        await provider.loadDrinks();

        final now = DateTime(2026, 6, 10, 18, 30);
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-b': UserDrinkState(
            tastingEvents: [now],
            notes: 'Surprisingly hoppy',
            createdAt: now,
            updatedAt: now,
          ),
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Surprisingly hoppy'), findsOneWidget);
      });

      testWidgets('renders no note line when the entry has no note', (
        tester,
      ) async {
        await setUpProvider();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [wantToTryDrink]);
        await provider.loadDrinks();

        final now = DateTime.now();
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-a': UserDrinkState(
            wantToTry: true,
            createdAt: now,
            updatedAt: now,
          ),
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Facts line still shown, but no italic note line is rendered.
        expect(find.text('Test Brewery • 4.2%'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text && widget.style?.fontStyle == FontStyle.italic,
          ),
          findsNothing,
        );
      });

      testWidgets('exposes the note in the want-to-try row Semantics label', (
        tester,
      ) async {
        await setUpProvider();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [wantToTryDrink]);
        await provider.loadDrinks();

        final now = DateTime.now();
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-a': UserDrinkState(
            wantToTry: true,
            notes: 'Tom recommended this',
            createdAt: now,
            updatedAt: now,
          ),
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label ==
                    'Alpha Ale, 4.2% ABV, by Test Brewery, want to try, '
                        'your note: Tom recommended this',
          ),
          findsOneWidget,
        );
      });
    });

    group('want to try enrichment', () {
      Drink wantDrink({String? status, String? style}) => Drink(
        product: Product(
          id: 'drink-a',
          name: 'Alpha Ale',
          abv: 4.2,
          category: 'beer',
          dispense: 'cask',
          style: style,
          statusText: status,
        ),
        producer: producer,
        festivalId: 'cbf2025',
      );

      Future<void> pumpWantToTry(WidgetTester tester, Drink drink) async {
        await setUpProvider();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink]);
        await provider.loadDrinks();
        final now = DateTime.now();
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-a': UserDrinkState(
            wantToTry: true,
            createdAt: now,
            updatedAt: now,
          ),
        });
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
      }

      testWidgets('shows style and ABV in the facts line', (tester) async {
        await pumpWantToTry(tester, wantDrink(style: 'IPA'));
        expect(find.text('Test Brewery • IPA • 4.2%'), findsOneWidget);
      });

      testWidgets('shows an at-risk availability hint (sold out)', (
        tester,
      ) async {
        await pumpWantToTry(tester, wantDrink(status: 'sold out'));
        expect(find.text('Sold Out'), findsOneWidget);
        // And the phrase is in the row's Semantics label for screen readers.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label?.contains('Sold out') ?? false),
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows a "Low" hint when stock is low', (tester) async {
        await pumpWantToTry(tester, wantDrink(status: 'a little remaining'));
        expect(find.text('Low'), findsOneWidget);
      });

      testWidgets('shows a "Nearly Gone" hint when stock is very low', (
        tester,
      ) async {
        await pumpWantToTry(tester, wantDrink(status: 'nearly finished!'));
        expect(find.text('Nearly Gone'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label?.contains('Nearly gone') ?? false),
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows no hint when the drink is comfortably available', (
        tester,
      ) async {
        await pumpWantToTry(tester, wantDrink(status: 'plenty left'));
        expect(find.text('Sold Out'), findsNothing);
        expect(find.text('Low'), findsNothing);
        expect(find.text('Nearly Gone'), findsNothing);
      });

      testWidgets('does not add an availability hint to tasted rows', (
        tester,
      ) async {
        // Tasted timeline stays lean even when the drink is sold out.
        await setUpProvider();
        final soldOut = Drink(
          product: const Product(
            id: 'drink-b',
            name: 'Beta Bitter',
            abv: 3.8,
            category: 'beer',
            dispense: 'cask',
            statusText: 'sold out',
          ),
          producer: producer,
          festivalId: 'cbf2025',
        );
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [soldOut]);
        await provider.loadDrinks();
        final now = DateTime(2026, 6, 10, 18, 30);
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-b': UserDrinkState(
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        });
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('tasted-drink-b')), findsOneWidget);
        expect(find.text('Sold Out'), findsNothing);
      });
    });

    group('semantics', () {
      testWidgets('section header and row have Semantics labels', (
        tester,
      ) async {
        await setUpProvider();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [wantToTryDrink]);
        await provider.loadDrinks();

        final now = DateTime.now();
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-a': UserDrinkState(
            wantToTry: true,
            createdAt: now,
            updatedAt: now,
          ),
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Section header Semantics label.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Want to Try section, 1 drink',
          ),
          findsOneWidget,
        );

        // Row Semantics label — and it excludes the ListTile's own child nodes
        // so screen readers announce the row once, not twice.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.excludeSemantics &&
                widget.properties.label ==
                    'Alpha Ale, 4.2% ABV, by Test Brewery, want to try',
          ),
          findsOneWidget,
        );
      });
    });

    group('app bar contrast', () {
      // Regression: the text theme bakes colorScheme.onSurface into every
      // style, so passing titleMedium/bodySmall straight into the AppBar
      // painted near-black text on the navy bar — 1.45:1 and 1.27:1 against
      // WCAG AA's 4.5:1 minimum. Assert the rendered text is light, and that
      // it actually clears AA against the bar it sits on.
      double relativeLuminance(Color c) {
        double channel(double v) => v <= 0.03928
            ? v / 12.92
            : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
        return 0.2126 * channel(c.r) +
            0.7152 * channel(c.g) +
            0.0722 * channel(c.b);
      }

      double contrastRatio(Color a, Color b) {
        final la = relativeLuminance(a);
        final lb = relativeLuminance(b);
        final lighter = la > lb ? la : lb;
        final darker = la > lb ? lb : la;
        return (lighter + 0.05) / (darker + 0.05);
      }

      testWidgets('title and subtitle meet WCAG AA on the app bar', (
        tester,
      ) async {
        await setUpProvider();
        // Must pump the real app theme: with the default theme the app bar is
        // not navy and the regression cannot reproduce.
        await tester.pumpWidget(
          createTestWidget(theme: buildAppTheme(Brightness.light)),
        );
        await tester.pumpAndSettle();

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        final context = tester.element(find.byType(MyFestivalScreen));
        final theme = Theme.of(context);
        final background =
            appBar.backgroundColor ??
            theme.appBarTheme.backgroundColor ??
            theme.colorScheme.surface;

        final titles = find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(Text),
        );
        expect(titles, findsWidgets);

        for (final text in tester.widgetList<Text>(titles)) {
          final color = text.style?.color;
          expect(
            color,
            isNotNull,
            reason: 'app bar text should pin an explicit colour',
          );
          expect(
            contrastRatio(color!, background),
            greaterThanOrEqualTo(4.5),
            reason:
                '"${text.data}" only reaches '
                '${contrastRatio(color, background).toStringAsFixed(2)}:1 '
                'against the app bar',
          );
        }
      });
    });

    group('card styling', () {
      // A want-to-try drink with a style and a low-stock status, so the goldens
      // capture the enriched facts line and the availability hint together.
      final wantToTryLowStock = Drink(
        product: const Product(
          id: 'drink-a',
          name: 'Alpha Ale',
          abv: 4.2,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
          statusText: 'a little remaining',
        ),
        producer: producer,
        festivalId: 'cbf2025',
      );

      testWidgets('rows are wrapped in a card with a category accent edge', (
        tester,
      ) async {
        await setUpProvider();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [wantToTryDrink]);
        await provider.loadDrinks();

        final now = DateTime.now();
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-a': UserDrinkState(
            wantToTry: true,
            createdAt: now,
            updatedAt: now,
          ),
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // The row is carded.
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('want-to-try-drink-a')),
            matching: find.byType(Card),
          ),
          findsOneWidget,
        );

        // ...with a 4px left accent edge in the beverage's category colour.
        // Scope the lookup to this row's own DecoratedBox so unrelated
        // decorations elsewhere on the screen can't satisfy (or break) it.
        final edgeFinder = find.ancestor(
          of: find.byKey(const ValueKey('want-to-try-drink-a')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).border is Border,
          ),
        );
        expect(edgeFinder, findsOneWidget);

        // Read brightness from the pumped tree rather than assuming light, so
        // this assertion holds if the harness theme ever changes.
        final accent = CategoryColorHelper.getAccentColor(
          'beer',
          Theme.of(tester.element(edgeFinder)).brightness,
        );
        final border =
            (tester.widget<DecoratedBox>(edgeFinder).decoration
                        as BoxDecoration)
                    .border
                as Border;
        expect(border.left.color, accent);
        expect(border.left.width, 4);
      });

      testWidgets('My Festival screen - light theme', (tester) async {
        await setUpProvider();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [wantToTryLowStock, tastedOnlyDrink]);
        await provider.loadDrinks();

        final now = DateTime(2026, 6, 10, 18, 30);
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-a': UserDrinkState(
            wantToTry: true,
            notes: 'Tom recommended this',
            createdAt: now,
            updatedAt: now,
          ),
          'drink-b': UserDrinkState(
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        });

        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          createTestWidget(theme: _goldenTheme(Brightness.light)),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MyFestivalScreen),
          matchesGoldenFile('goldens/my_festival_screen_light.png'),
        );
      });

      testWidgets('My Festival screen - dark theme', (tester) async {
        await setUpProvider();
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [wantToTryLowStock, tastedOnlyDrink]);
        await provider.loadDrinks();

        final now = DateTime(2026, 6, 10, 18, 30);
        when(mockDrinkRepository.getPersonalEntries(any)).thenReturn({
          'drink-a': UserDrinkState(
            wantToTry: true,
            notes: 'Tom recommended this',
            createdAt: now,
            updatedAt: now,
          ),
          'drink-b': UserDrinkState(
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        });

        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          createTestWidget(theme: _goldenTheme(Brightness.dark)),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MyFestivalScreen),
          matchesGoldenFile('goldens/my_festival_screen_dark.png'),
        );
      });
    });
  });
}
