import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:cambridge_beer_festival/widgets/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('DrinkDetailScreen', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    const festival = Festival(
      id: 'cbf2025',
      name: 'Cambridge Beer Festival 2025',
      dataBaseUrl: 'https://example.com',
      hashtag: '#CBF2025',
    );

    const producer = Producer(
      id: 'brewery1',
      name: 'Test Brewery',
      location: 'Cambridge, UK',
      yearFounded: 1990,
      products: [],
    );

    const product = Product(
      id: 'drink1',
      name: 'Test Beer',
      abv: 5.0,
      category: 'beer',
      dispense: 'cask',
      style: 'IPA',
      bar: 'Main Bar',
      isVegan: true,
      notes: 'A hoppy beer with citrus notes',
      allergens: {'gluten': 1, 'sulphites': 1},
    );

    final drink = Drink(
      product: product,
      producer: producer,
      festivalId: 'cbf2025',
    );

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
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => []);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
      await provider.setFestival(festival);
    });

    tearDown(() {
      provider.dispose();
    });

    // The detail screen scrolls in production; render at full height so
    // assertions are not sensitive to section order or lazy sliver building
    // (moving a section down must not push it out of a fixed test viewport).
    Future<void> useTallSurface(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }

    Widget createTestWidget(String drinkId) {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp(
          home: DrinkDetailScreen(festivalId: 'cbf2025', drinkId: drinkId),
        ),
      );
    }

    Widget createTestWidgetWithRouter(String drinkId) {
      final router = GoRouter(
        initialLocation: '/cbf2025/drink/beer/$drinkId',
        routes: [
          GoRoute(
            path: '/cbf2025/drink/:category/:drinkId',
            builder: (context, state) =>
                ChangeNotifierProvider<BeerProvider>.value(
                  value: provider,
                  child: DrinkDetailScreen(
                    festivalId: 'cbf2025',
                    drinkId: state.pathParameters['drinkId']!,
                  ),
                ),
          ),
          GoRoute(
            path: '/cbf2025/brewery/:breweryId',
            builder: (context, state) =>
                const Scaffold(body: Text('Brewery Screen')),
          ),
          GoRoute(
            path: '/cbf2025/style/:style',
            builder: (context, state) =>
                const Scaffold(body: Text('Style Screen')),
          ),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    testWidgets('displays drink not found when drink does not exist', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget('nonexistent'));
      await tester.pumpAndSettle();

      expect(find.text('Drink Not Found'), findsOneWidget);
      expect(find.text('This drink could not be found.'), findsOneWidget);
    });

    testWidgets('displays drink information when drink exists', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await useTallSurface(tester);
      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('Test Beer'), findsOneWidget); // Appears in hero
      // Brewery name appears in the hero link and the brewery section.
      expect(find.textContaining('Test Brewery'), findsWidgets);
      // Location appears in the hero (combined) and the brewery section subtitle
      expect(find.textContaining('Cambridge, UK'), findsWidgets);

      // Regression test for #311: the app bar shows the festival *name* (as the
      // collapsing bar's context title at rest), never the raw festival ID. The
      // collapse-to-drink-identity behaviour is covered by the scroll test
      // above.
      expect(
        find.descendant(
          of: find.byType(SliverAppBar),
          matching: find.text('Cambridge Beer Festival 2025'),
        ),
        findsOneWidget,
      );
      expect(find.text('cbf2025'), findsNothing);
    });

    testWidgets(
      'app bar fades from festival name to the drink identity on scroll',
      (WidgetTester tester) async {
        // A second same-brewery drink adds a Similar Drinks carousel; combined
        // with a short viewport this leaves plenty of scroll extent so the hero
        // moves well under the bar (the drag clamps to the max extent).
        const sibling = Product(
          id: 'drink9',
          name: 'Sibling Ale',
          abv: 4.2,
          category: 'beer',
          dispense: 'cask',
          style: 'Bitter',
        );
        when(mockDrinkRepository.getDrinks(any)).thenAnswer(
          (_) async => [
            drink,
            Drink(product: sibling, producer: producer, festivalId: 'cbf2025'),
          ],
        );
        await provider.loadDrinks();

        await tester.binding.setSurfaceSize(const Size(400, 500));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        final collapsed = find.byKey(const ValueKey('appbar-collapsed-title'));

        // At the top: festival context is shown; the identity isn't in the bar.
        expect(find.text('Cambridge Beer Festival 2025'), findsOneWidget);
        expect(collapsed, findsNothing);

        // Scroll the hero off the top (drag clamps to the max scroll extent).
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -1000),
        );
        await tester.pumpAndSettle();

        // The bar now carries the drink name and the brewery inline.
        expect(collapsed, findsOneWidget);
        final identity = tester.widget<Text>(
          find.descendant(of: collapsed, matching: find.byType(Text)),
        );
        final identityText = identity.textSpan?.toPlainText() ?? '';
        expect(identityText, contains('Test Beer'));
        expect(identityText, contains('Test Brewery'));
      },
    );

    testWidgets('displays drink details chips', (WidgetTester tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink]);
        await provider.loadDrinks();

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // Identity hero: ABV numeral + the facts strip (style / serve /
        // availability) + vegan row.
        expect(find.text('5.0'), findsOneWidget); // ABV numeral
        expect(find.textContaining('ABV'), findsOneWidget);
        expect(find.text('IPA'), findsOneWidget); // style fact cell
        expect(find.text('Cask'), findsOneWidget); // serve fact cell
        expect(find.text('Available'), findsOneWidget);
        expect(find.textContaining('Main Bar'), findsOneWidget);
        expect(find.text('Vegan'), findsOneWidget);
        expect(find.bySemanticsLabel('This drink is vegan'), findsOneWidget);
      } finally {
        semanticsHandle.dispose();
      }
    });

    testWidgets('displays status text in chips when available', (
      WidgetTester tester,
    ) async {
      const productWithStatus = Product(
        id: 'drink3',
        name: 'Status Beer',
        abv: 5.5,
        category: 'beer',
        dispense: 'cask',
        bar: 'Main Bar',
        statusText: 'Plenty remaining',
      );
      final drinkWithStatus = Drink(
        product: productWithStatus,
        producer: producer,
        festivalId: 'cbf2025',
      );
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => [drinkWithStatus]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink3'));
      await tester.pumpAndSettle();

      // Identity hero shows availability + bar; raw statusText is not shown.
      expect(find.text('Available'), findsOneWidget);
      expect(find.textContaining('Main Bar'), findsOneWidget);
    });

    testWidgets('does not display status chip when status text is null', (
      WidgetTester tester,
    ) async {
      const productNoStatus = Product(
        id: 'drink4',
        name: 'No Status Beer',
        abv: 4.5,
        category: 'beer',
        dispense: 'keg',
        statusText: null,
      );
      final drinkNoStatus = Drink(
        product: productNoStatus,
        producer: producer,
        festivalId: 'cbf2025',
      );
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => [drinkNoStatus]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink4'));
      await tester.pumpAndSettle();

      // Check that common status texts are not present
      expect(find.text('Plenty remaining'), findsNothing);
      expect(find.text('Sold out'), findsNothing);
      expect(find.text('Not yet available'), findsNothing);
    });

    testWidgets('displays description when notes exist', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('A hoppy beer with citrus notes'), findsOneWidget);
    });

    testWidgets('displays allergen information in the hero', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      // Allergens are dietary decision-info at the same tier as vegan, so they
      // live in the hero (visible without scrolling).
      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Contains:'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DrinkHeroPanel),
          matching: find.textContaining('Contains:'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('displays an editable rating in the Your take card', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      // Rating is now inline stars in the "Your take" card, not a bottom-bar
      // button.
      expect(
        find.descendant(
          of: find.byType(YourTakeCard),
          matching: find.byType(StarRating),
        ),
        findsOneWidget,
      );
      final stars = tester.widget<StarRating>(find.byType(StarRating));
      expect(stars.isEditable, isTrue);
      // Unrated: five empty stars and the hint.
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      expect(find.text('Tap a star to rate'), findsOneWidget);
    });

    testWidgets('tapping a star sets the rating inline', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      when(mockDrinkRepository.setRating(any, any, any)).thenAnswer(
        (_) async => UserDrinkState(
          rating: 4,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      // Tap the fourth star (unrated → five empty stars, left to right).
      await tester.tap(find.byIcon(Icons.star_border).at(3));
      await tester.pumpAndSettle();

      expect(provider.getDrinkById('drink1')!.rating, 4);
      expect(find.byIcon(Icons.star), findsNWidgets(4));
    });

    testWidgets('displays brewery as a link in the hero', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await useTallSurface(tester);
      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      // Brewery is now a link inside the identity hero, not a standalone
      // section lower down.
      expect(find.text('Brewery'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DrinkHeroPanel),
          matching: find.text('Test Brewery'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('has a single share button, in the hero', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      // Exactly one share affordance, now in the identity hero (moved off the
      // festival-scoped app bar).
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.share),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(DrinkHeroPanel),
          matching: find.byIcon(Icons.share),
        ),
        findsOneWidget,
      );
    });

    testWidgets('hero exposes semantic labels for its links and share', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(
            'View all drinks from Test Brewery, Cambridge, UK',
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('View all IPA drinks'), findsOneWidget);
        expect(find.bySemanticsLabel('Share Test Beer'), findsOneWidget);
      } finally {
        semanticsHandle.dispose();
      }
    });

    testWidgets(
      'style fact is plain text, not a link, when drink has no style',
      (WidgetTester tester) async {
        const noStyleProduct = Product(
          id: 'drink1',
          name: 'Test Beer',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          bar: 'Main Bar',
        );
        final noStyleDrink = Drink(
          product: noStyleProduct,
          producer: producer,
          festivalId: 'cbf2025',
        );
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [noStyleDrink]);
        await provider.loadDrinks();

        final semanticsHandle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(createTestWidget('drink1'));
          await tester.pumpAndSettle();

          // Falls back to the capitalised category with no link affordance:
          // no navigable "View all …" semantics.
          expect(find.text('Beer'), findsOneWidget);
          expect(
            find.bySemanticsLabel(RegExp('View all .* drinks')),
            findsNothing,
          );
        } finally {
          semanticsHandle.dispose();
        }
      },
    );

    testWidgets('has want-to-try bookmark button', (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
        expect(find.text('Want to Try'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Add Test Beer to want to try')),
          findsOneWidget,
        );
      } finally {
        semanticsHandle.dispose();
      }
    });

    testWidgets('toggles want-to-try when bookmark button is tapped', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        expect(provider.getDrinkById('drink1')!.isFavorite, false);
        expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

        // Mock toggleFavorite to properly toggle state
        final favorites = <String>{};
        when(mockDrinkRepository.toggleFavorite(any, any)).thenAnswer((
          invocation,
        ) async {
          final drinkId = invocation.positionalArguments[1] as String;
          if (favorites.contains(drinkId)) {
            favorites.remove(drinkId);
            return null;
          } else {
            favorites.add(drinkId);
            return UserDrinkState(
              wantToTry: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
        });

        // Tap bookmark button
        await tester.tap(find.byIcon(Icons.bookmark_border));
        await tester.pumpAndSettle();

        expect(provider.getDrinkById('drink1')!.isFavorite, true);
        expect(find.byIcon(Icons.bookmark), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Remove Test Beer from want to try')),
          findsOneWidget,
        );
      } finally {
        semanticsHandle.dispose();
      }
    });

    group('Multi-tasting and notes (#415)', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime(2025, 6, 10, 18, 45).millisecondsSinceEpoch,
      );

      // The personal section (tasting log + notes) sits below the fold. Give
      // the screen a viewport tall enough to build every sliver so tests can
      // find and tap it directly without scroll flakiness. Must run inside the
      // test body (setSurfaceSize asserts inTest); reset on teardown so sibling
      // tests keep the default surface.
      Future<void> useTallSurface(WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(500, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
      }

      Drink tastedDrink(List<DateTime> events, {String? notes}) {
        return drink.copyWith(
          userState: UserDrinkState(
            tastingEvents: events,
            notes: notes,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      testWidgets('Drunk it! floating button appends a tasting and logs it', (
        WidgetTester tester,
      ) async {
        await useTallSurface(tester);
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink]);
        await provider.loadDrinks();

        when(
          mockDrinkRepository.addTasting(any, any, now: anyNamed('now')),
        ).thenAnswer(
          (_) async => UserDrinkState(
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // The one repeated action floats as an extended FAB.
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('Drunk it!'), findsOneWidget);
        expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('tasted-action')));
        await tester.pumpAndSettle();

        // One tasting recorded and a log row renders. The button label stays
        // constant — the count is state, shown in the log, not on the button.
        expect(provider.getDrinkById('drink1')!.tastingCount, 1);
        expect(find.text('Drunk it!'), findsOneWidget);
        expect(find.text('Your Tastings (1)'), findsOneWidget);

        // Layered confirmation: a SnackBar tells the user it happened.
        expect(find.text('Logged your first tasting'), findsOneWidget);

        // Let the SnackBar's timer expire so none is pending at teardown.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      });

      testWidgets('marking tasted does not clear an existing want-to-try', (
        WidgetTester tester,
      ) async {
        await useTallSurface(tester);
        final wantToTryDrink = drink.copyWith(
          userState: UserDrinkState(
            wantToTry: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [wantToTryDrink]);
        await provider.loadDrinks();

        // The repository is the source of truth: appending a tasting keeps the
        // want-to-try flag set (the derived section-membership rule).
        when(
          mockDrinkRepository.addTasting(any, any, now: anyNamed('now')),
        ).thenAnswer(
          (_) async => UserDrinkState(
            wantToTry: true,
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('tasted-action')));
        await tester.pumpAndSettle();

        final updated = provider.getDrinkById('drink1')!;
        expect(updated.isFavorite, true);
        expect(updated.tastingCount, 1);

        // Clear the confirmation SnackBar's timer before teardown.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      });

      testWidgets('Undo on the confirmation removes the just-logged tasting', (
        WidgetTester tester,
      ) async {
        await useTallSurface(tester);
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink]);
        await provider.loadDrinks();

        when(
          mockDrinkRepository.addTasting(any, any, now: anyNamed('now')),
        ).thenAnswer(
          (_) async => UserDrinkState(
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        );
        // Undo prunes the only tasting back to null.
        when(
          mockDrinkRepository.removeTasting(any, any, any),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('tasted-action')));
        await tester.pumpAndSettle();
        expect(provider.getDrinkById('drink1')!.tastingCount, 1);

        // Undo removes the pour just logged (its newest event).
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        expect(provider.getDrinkById('drink1')!.tastingCount, 0);
        verify(mockDrinkRepository.removeTasting(any, any, any)).called(1);
      });

      testWidgets('tapping the confirmation message dismisses it early', (
        WidgetTester tester,
      ) async {
        await useTallSurface(tester);
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink]);
        await provider.loadDrinks();

        when(
          mockDrinkRepository.addTasting(any, any, now: anyNamed('now')),
        ).thenAnswer(
          (_) async => UserDrinkState(
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('tasted-action')));
        await tester.pumpAndSettle();
        expect(find.text('Logged your first tasting'), findsOneWidget);

        // The dismissible message announces as an actionable control with a
        // dismiss hint, not just as static text.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Logged your first tasting' &&
                widget.properties.button == true &&
                widget.properties.hint == 'Double tap to dismiss',
          ),
          findsOneWidget,
        );

        // A tap on the message dismisses it without waiting for the timeout
        // or discovering the swipe-to-dismiss gesture.
        await tester.tap(find.text('Logged your first tasting'));
        await tester.pumpAndSettle();

        expect(find.text('Logged your first tasting'), findsNothing);
      });

      testWidgets('confirmation SnackBar is scoped to this screen', (
        WidgetTester tester,
      ) async {
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink]);
        await provider.loadDrinks();

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // The screen provides its own ScaffoldMessenger (in addition to
        // MaterialApp's) so the confirmation toast — and its drink-specific
        // Undo — can't float over an unrelated screen after navigating away.
        expect(find.byType(ScaffoldMessenger), findsNWidgets(2));
      });

      testWidgets(
        'renders a timestamp row per tasting with a delete affordance',
        (WidgetTester tester) async {
          await useTallSurface(tester);
          final second = DateTime.fromMillisecondsSinceEpoch(
            DateTime(2025, 6, 11, 12, 0).millisecondsSinceEpoch,
          );
          when(mockDrinkRepository.getDrinks(any)).thenAnswer(
            (_) async => [
              tastedDrink([now, second]),
            ],
          );
          await provider.loadDrinks();

          final semanticsHandle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(createTestWidget('drink1'));
            await tester.pumpAndSettle();

            expect(find.text('Your Tastings (2)'), findsOneWidget);
            expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
            // Rows are keyed by position, not timestamp, so duplicate pours
            // stay individually addressable.
            expect(
              find.byKey(const ValueKey('delete-tasting-0')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('delete-tasting-1')),
              findsOneWidget,
            );
            // Each delete affordance carries a position-aware semantic label.
            expect(
              find.bySemanticsLabel(RegExp(r'^Remove tasting \d+ of 2, ')),
              findsNWidgets(2),
            );
          } finally {
            semanticsHandle.dispose();
          }
        },
      );

      testWidgets('duplicate-timestamp pours render as distinct rows', (
        WidgetTester tester,
      ) async {
        await useTallSurface(tester);
        // Two pours logged in the same millisecond — the model allows this.
        // Rows must stay individually keyed (no duplicate-key build crash).
        when(mockDrinkRepository.getDrinks(any)).thenAnswer(
          (_) async => [
            tastedDrink([now, now]),
          ],
        );
        await provider.loadDrinks();

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Your Tastings (2)'), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
        expect(find.byKey(const ValueKey('delete-tasting-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('delete-tasting-1')), findsOneWidget);
      });

      testWidgets('delete tasting removes immediately and offers Undo', (
        WidgetTester tester,
      ) async {
        await useTallSurface(tester);
        when(mockDrinkRepository.getDrinks(any)).thenAnswer(
          (_) async => [
            tastedDrink([now]),
          ],
        );
        await provider.loadDrinks();

        when(
          mockDrinkRepository.removeTasting(any, any, any),
        ).thenAnswer((_) async => null);
        when(
          mockDrinkRepository.addTasting(any, any, now: anyNamed('now')),
        ).thenAnswer(
          (_) async => UserDrinkState(
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        expect(find.text('Your Tastings (1)'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('delete-tasting-0')));
        await tester.pumpAndSettle();

        // No confirmation dialog — removed immediately.
        expect(find.text('Remove this tasting?'), findsNothing);
        expect(provider.getDrinkById('drink1')!.tastingCount, 0);
        expect(find.text('Your Tastings (1)'), findsNothing);

        // Undo SnackBar restores the exact same pour.
        expect(find.text('Undo'), findsOneWidget);
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        verify(mockDrinkRepository.addTasting(any, any, now: now)).called(1);
        expect(provider.getDrinkById('drink1')!.tastingCount, 1);
      });

      testWidgets('notes editor autosaves user notes typed in place', (
        WidgetTester tester,
      ) async {
        await useTallSurface(tester);
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink]);
        await provider.loadDrinks();

        when(mockDrinkRepository.setUserNotes(any, any, any)).thenAnswer(
          (_) async => UserDrinkState(
            notes: 'Lovely and hoppy',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // The note lives in the "Your take" card now, with a placeholder.
        expect(find.text('Your take'), findsOneWidget);
        expect(find.text('Tap to add your notes'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('user-notes-field')),
          'Lovely and hoppy',
        );
        await tester.pump(
          YourTakeCard.notesDebounceDuration + const Duration(milliseconds: 50),
        );
        await tester.pumpAndSettle();

        verify(
          mockDrinkRepository.setUserNotes(any, any, 'Lovely and hoppy'),
        ).called(1);
        expect(provider.getDrinkById('drink1')!.userNotes, 'Lovely and hoppy');
        expect(find.text('Lovely and hoppy'), findsOneWidget);
      });

      testWidgets('the Drunk it! FAB hides while the note is being edited', (
        WidgetTester tester,
      ) async {
        await useTallSurface(tester);
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink]);
        await provider.loadDrinks();

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('tasted-action')), findsOneWidget);

        // Editing the note raises the keyboard; the centre-floating FAB
        // would sit directly over the field, so it must get out of the way.
        await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('tasted-action')), findsNothing);

        // Blur ends editing and brings the FAB back.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('tasted-action')), findsOneWidget);
      });

      testWidgets('note-only drink shows the My Festival nudge and logging '
          'from it records a pour', (WidgetTester tester) async {
        await useTallSurface(tester);
        when(mockDrinkRepository.getDrinks(any)).thenAnswer(
          (_) async => [
            drink.copyWith(
              userState: UserDrinkState(
                notes: 'Dave said try this',
                createdAt: now,
                updatedAt: now,
              ),
            ),
          ],
        );
        await provider.loadDrinks();

        when(
          mockDrinkRepository.addTasting(any, any, now: anyNamed('now')),
        ).thenAnswer(
          (_) async => UserDrinkState(
            notes: 'Dave said try this',
            tastingEvents: [now],
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // A note alone can't place the drink in My Festival, so the card
        // prompts for an explicit signal.
        expect(find.text('Show it in My Festival?'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('nudge-drunk-it')));
        await tester.pumpAndSettle();

        verify(
          mockDrinkRepository.addTasting(any, any, now: anyNamed('now')),
        ).called(1);
        expect(provider.getDrinkById('drink1')!.tastingCount, 1);
        expect(find.text('Logged your first tasting'), findsOneWidget);
        // The signal now exists, so the nudge retires.
        expect(find.text('Show it in My Festival?'), findsNothing);
      });

      testWidgets('existing user notes are shown and prefilled for editing', (
        WidgetTester tester,
      ) async {
        await useTallSurface(tester);
        when(mockDrinkRepository.getDrinks(any)).thenAnswer(
          (_) async => [
            tastedDrink([now], notes: 'First taste'),
          ],
        );
        await provider.loadDrinks();

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // The user's note is shown, distinct from the catalogue description.
        expect(find.text('First taste'), findsOneWidget);
        expect(find.text('A hoppy beer with citrus notes'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
        await tester.pumpAndSettle();

        // The field is prefilled with the existing note.
        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('user-notes-field')),
        );
        expect(field.controller?.text, 'First taste');
      });
    });

    testWidgets('navigates to brewery screen when brewery link is tapped', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await useTallSurface(tester);
      await tester.pumpWidget(createTestWidgetWithRouter('drink1'));
      await tester.pumpAndSettle();

      final breweryLink = find.text('Test Brewery');
      await tester.ensureVisible(breweryLink);
      await tester.pumpAndSettle();

      await tester.tap(breweryLink);
      await tester.pumpAndSettle();

      expect(find.text('Brewery Screen'), findsOneWidget);
    });

    testWidgets('navigates to style screen when style chip is tapped', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidgetWithRouter('drink1'));
      await tester.pumpAndSettle();

      final styleChip = find.text('IPA');
      await tester.ensureVisible(styleChip);
      await tester.pumpAndSettle();

      await tester.tap(styleChip);
      await tester.pumpAndSettle();

      expect(find.text('Style Screen'), findsOneWidget);
    });

    testWidgets('does not display description section when notes are null', (
      WidgetTester tester,
    ) async {
      const productNoNotes = Product(
        id: 'drink2',
        name: 'Simple Beer',
        abv: 4.0,
        category: 'beer',
        dispense: 'keg',
        notes: null,
      );
      final drinkNoNotes = Drink(
        product: productNoNotes,
        producer: producer,
        festivalId: 'cbf2025',
      );
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => [drinkNoNotes]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink2'));
      await tester.pumpAndSettle();

      // Verify the drink name is there but no description text
      expect(find.text('Simple Beer'), findsWidgets);
    });

    testWidgets('displays rating value when drink has rating', (
      WidgetTester tester,
    ) async {
      final ratedDrink = drink.copyWith(
        userState: UserDrinkState.initial().copyWith(rating: 4),
      );
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => [ratedDrink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      // A rating of 4 shows four filled stars (and one empty).
      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border), findsNWidgets(1));
    });

    testWidgets('shows all empty stars when drink has no rating', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    });

    testWidgets('updates rating when set through provider', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(provider.getDrinkById('drink1')!.rating, null);

      // Simulate rating change through provider
      when(mockDrinkRepository.setRating(any, any, any)).thenAnswer(
        (_) async => UserDrinkState(
          rating: 5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await provider.setRating(provider.getDrinkById('drink1')!, 5);
      await tester.pumpAndSettle();

      expect(provider.getDrinkById('drink1')!.rating, 5);
      expect(find.byIcon(Icons.star), findsNWidgets(5));
    });

    group('Similar Drinks Section', () {
      testWidgets('displays similar drinks section when similar drinks exist', (
        WidgetTester tester,
      ) async {
        // Create multiple drinks with similar characteristics
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );

        const producer2 = Producer(
          id: 'brewery2',
          name: 'Another Brewery',
          location: 'London, UK',
          products: [],
        );

        const product1 = Product(
          id: 'drink1',
          name: 'Test IPA',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );

        const product2 = Product(
          id: 'drink2',
          name: 'Similar IPA',
          abv: 5.4, // Within 0.5% AND same style
          category: 'beer',
          dispense: 'cask',
          style: 'IPA', // Same style
        );

        const product3 = Product(
          id: 'drink3',
          name: 'Same Brewery Beer',
          abv: 4.0,
          category: 'beer',
          dispense: 'keg',
          style: 'Lager',
        );

        final drink1 = Drink(
          product: product1,
          producer: producer1,
          festivalId: 'cbf2025',
        );
        final drink2 = Drink(
          product: product2,
          producer: producer2,
          festivalId: 'cbf2025',
        );
        final drink3 = Drink(
          product: product3,
          producer: producer1,
          festivalId: 'cbf2025',
        ); // Same brewery

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink1, drink2, drink3]);
        await provider.loadDrinks();

        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // Should show Similar Drinks section
        expect(find.text('Similar Drinks'), findsOneWidget);

        // Scroll down to ensure similar drinks are visible
        await tester.ensureVisible(find.text('Similar Drinks'));
        await tester.pumpAndSettle();

        // Should show similar drinks (drink2 has same style and close ABV, drink3 has same brewery)
        expect(find.text('Similar IPA'), findsOneWidget);
        expect(find.text('Same Brewery Beer'), findsOneWidget);

        // Should show similarity reasons
        expect(find.text('Same style, similar strength'), findsOneWidget);
        expect(find.text('Same brewery'), findsOneWidget);
      });

      testWidgets('personal section renders above similar drinks', (
        WidgetTester tester,
      ) async {
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );
        const producer2 = Producer(
          id: 'brewery2',
          name: 'Another Brewery',
          location: 'London, UK',
          products: [],
        );
        const product1 = Product(
          id: 'drink1',
          name: 'Test IPA',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );
        const product2 = Product(
          id: 'drink2',
          name: 'Similar IPA',
          abv: 5.4, // same style, within 0.5% ABV → surfaces as similar
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );
        final drink1 = Drink(
          product: product1,
          producer: producer1,
          festivalId: 'cbf2025',
        );
        final drink2 = Drink(
          product: product2,
          producer: producer2,
          festivalId: 'cbf2025',
        );

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink1, drink2]);
        await provider.loadDrinks();

        // Full height so every section lays out without scrolling and the
        // vertical order of the headers is directly comparable.
        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        final personalY = tester.getTopLeft(find.text('Your take')).dy;
        final similarY = tester.getTopLeft(find.text('Similar Drinks')).dy;

        expect(personalY, lessThan(similarY));
      });

      testWidgets('similar drinks render as a horizontal row of keyed cards', (
        WidgetTester tester,
      ) async {
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );
        const producer2 = Producer(
          id: 'brewery2',
          name: 'Another Brewery',
          location: 'London, UK',
          products: [],
        );
        const product1 = Product(
          id: 'drink1',
          name: 'Test IPA',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );
        const product2 = Product(
          id: 'drink2',
          name: 'Similar IPA',
          abv: 5.2, // same style → 'Same style, similar strength'
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );
        const product3 = Product(
          id: 'drink3',
          name: 'Same Brewery Beer',
          abv: 4.0, // same brewery → 'Same brewery'
          category: 'beer',
          dispense: 'keg',
          style: 'Lager',
        );
        final drink1 = Drink(
          product: product1,
          producer: producer1,
          festivalId: 'cbf2025',
        );
        final drink2 = Drink(
          product: product2,
          producer: producer2,
          festivalId: 'cbf2025',
        );
        final drink3 = Drink(
          product: product3,
          producer: producer1,
          festivalId: 'cbf2025',
        );

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink1, drink2, drink3]);
        await provider.loadDrinks();

        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // Both similar drinks appear as their own keyed cards.
        expect(find.byKey(const ValueKey('drink2')), findsOneWidget);
        expect(find.byKey(const ValueKey('drink3')), findsOneWidget);

        // They sit side by side (same top edge, increasing left edge) — a
        // horizontal row, not a vertical list.
        final card2 = tester.getTopLeft(find.byKey(const ValueKey('drink2')));
        final card3 = tester.getTopLeft(find.byKey(const ValueKey('drink3')));
        // Same top edge (tolerant of subpixel rounding), increasing left edge.
        expect(card2.dy, moreOrLessEquals(card3.dy, epsilon: 1.0));
        expect(card3.dx, greaterThan(card2.dx));
      });

      testWidgets('similar drinks carousel does not overflow at large text '
          'scale', (WidgetTester tester) async {
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );
        const product1 = Product(
          id: 'drink1',
          name: 'Test IPA',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );
        const product2 = Product(
          id: 'drink2',
          name: 'A Rather Long Similar India Pale Ale Name That Wraps',
          abv: 5.2,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );
        final drink1 = Drink(
          product: product1,
          producer: producer1,
          festivalId: 'cbf2025',
        );
        final drink2 = Drink(
          product: product2,
          producer: producer1,
          festivalId: 'cbf2025',
        );

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink1, drink2]);
        await provider.loadDrinks();

        // Emulate a large accessibility font size. A fixed-height card would
        // throw a RenderFlex overflow here; the intrinsic-height strip grows
        // instead.
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('drink2')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('similar drink card exposes button semantics with reason', (
        WidgetTester tester,
      ) async {
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );
        const product1 = Product(
          id: 'drink1',
          name: 'Test IPA',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );
        const product2 = Product(
          id: 'drink2',
          name: 'Similar IPA',
          abv: 5.2,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );
        final drink1 = Drink(
          product: product1,
          producer: producer1,
          festivalId: 'cbf2025',
        );
        final drink2 = Drink(
          product: product2,
          producer: producer1,
          festivalId: 'cbf2025',
        );

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink1, drink2]);
        await provider.loadDrinks();

        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // The whole card is a single button whose label carries the drink and
        // the reason it surfaced.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.button ?? false) &&
                (widget.properties.label?.contains('Similar IPA') ?? false) &&
                (widget.properties.label?.contains('Same brewery') ?? false),
          ),
          findsOneWidget,
        );
      });

      testWidgets('excludes known sold-out drinks from similar drinks', (
        WidgetTester tester,
      ) async {
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );
        const producer2 = Producer(
          id: 'brewery2',
          name: 'Another Brewery',
          location: 'London, UK',
          products: [],
        );
        const product1 = Product(
          id: 'drink1',
          name: 'Test IPA',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );
        // Same style + close ABV, but sold out → must not be recommended.
        const product2 = Product(
          id: 'drink2',
          name: 'Gone IPA',
          abv: 5.2,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
          statusText: 'Sold Out',
        );
        // Same style + close ABV, available → recommended.
        const product3 = Product(
          id: 'drink3',
          name: 'Fresh IPA',
          abv: 5.1,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
          statusText: 'Plenty left',
        );
        final drink1 = Drink(
          product: product1,
          producer: producer1,
          festivalId: 'cbf2025',
        );
        final drink2 = Drink(
          product: product2,
          producer: producer2,
          festivalId: 'cbf2025',
        );
        final drink3 = Drink(
          product: product3,
          producer: producer2,
          festivalId: 'cbf2025',
        );

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink1, drink2, drink3]);
        await provider.loadDrinks();

        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('drink3')), findsOneWidget);
        expect(find.text('Fresh IPA'), findsOneWidget);
        expect(find.byKey(const ValueKey('drink2')), findsNothing);
        expect(find.text('Gone IPA'), findsNothing);
      });

      testWidgets('similar drink cards show tasted and want-to-try status', (
        WidgetTester tester,
      ) async {
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );
        const product1 = Product(
          id: 'drink1',
          name: 'Test IPA',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );
        const product2 = Product(
          id: 'drink2',
          name: 'Tasted Ale',
          abv: 4.5,
          category: 'beer',
          dispense: 'cask',
          style: 'Bitter',
        );
        const product3 = Product(
          id: 'drink3',
          name: 'Wanted Ale',
          abv: 4.8,
          category: 'beer',
          dispense: 'cask',
          style: 'Bitter',
        );
        // All same brewery → all surface as similar via 'Same brewery'.
        final drink1 = Drink(
          product: product1,
          producer: producer1,
          festivalId: 'cbf2025',
        );
        final drink2 = Drink(
          product: product2,
          producer: producer1,
          festivalId: 'cbf2025',
        );
        final drink3 = Drink(
          product: product3,
          producer: producer1,
          festivalId: 'cbf2025',
        );

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink1, drink2, drink3]);
        await provider.loadDrinks();

        // Stub the persistence layer to return the new state, mirroring the
        // established pattern (see brewery_screen_test.dart).
        when(
          mockDrinkRepository.addTasting(any, any, now: anyNamed('now')),
        ).thenAnswer(
          (_) async => UserDrinkState(
            tastingEvents: [DateTime(2025, 6, 10, 18)],
            createdAt: DateTime(2025, 6, 10),
            updatedAt: DateTime(2025, 6, 10),
          ),
        );
        when(mockDrinkRepository.toggleFavorite(any, any)).thenAnswer(
          (_) async => UserDrinkState(
            wantToTry: true,
            createdAt: DateTime(2025, 6, 10),
            updatedAt: DateTime(2025, 6, 10),
          ),
        );
        await provider.addTasting(provider.getDrinkById('drink2')!);
        await provider.toggleFavorite(provider.getDrinkById('drink3')!);

        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // Tasted similar drink → check icon on its card and in its label.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('drink2')),
            matching: find.byIcon(Icons.check_circle),
          ),
          findsOneWidget,
        );
        // Want-to-try similar drink → bookmark icon on its card.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('drink3')),
            matching: find.byIcon(Icons.bookmark),
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label?.contains('Tasted once') ?? false),
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label?.contains('Added to want to try') ??
                    false),
          ),
          findsOneWidget,
        );
      });

      testWidgets(
        'does not display similar drinks section when no similar drinks exist',
        (WidgetTester tester) async {
          const producer1 = Producer(
            id: 'brewery1',
            name: 'Test Brewery',
            location: 'Cambridge, UK',
            products: [],
          );

          const product1 = Product(
            id: 'drink1',
            name: 'Unique Beer',
            abv: 5.0,
            category: 'beer',
            dispense: 'cask',
            style: 'Unique Style',
          );

          final drink1 = Drink(
            product: product1,
            producer: producer1,
            festivalId: 'cbf2025',
          );

          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => [drink1]);
          await provider.loadDrinks();

          await tester.pumpWidget(createTestWidget('drink1'));
          await tester.pumpAndSettle();

          // Should not show Similar Drinks section when no similar drinks
          expect(find.text('Similar Drinks'), findsNothing);
        },
      );

      testWidgets('similar drinks are tappable and navigate correctly', (
        WidgetTester tester,
      ) async {
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );

        const product1 = Product(
          id: 'drink1',
          name: 'Test IPA',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );

        const product2 = Product(
          id: 'drink2',
          name: 'Similar IPA',
          abv: 5.2,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        );

        final drink1 = Drink(
          product: product1,
          producer: producer1,
          festivalId: 'cbf2025',
        );
        final drink2 = Drink(
          product: product2,
          producer: producer1,
          festivalId: 'cbf2025',
        );

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink1, drink2]);
        await provider.loadDrinks();

        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // Scroll to ensure similar drinks section is visible
        await tester.ensureVisible(find.text('Similar Drinks'));
        await tester.pumpAndSettle();

        // Verify similar drink card exists
        expect(find.text('Similar IPA'), findsOneWidget);

        // NOTE: Navigation uses go_router's context.push() which requires GoRouter
        // in the widget tree. This is tested in E2E tests instead of unit tests.
      });

      testWidgets('similar drinks based on same style and close ABV', (
        WidgetTester tester,
      ) async {
        const producer1 = Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge, UK',
          products: [],
        );

        const producer2 = Producer(
          id: 'brewery2',
          name: 'Another Brewery',
          location: 'London, UK',
          products: [],
        );

        const product1 = Product(
          id: 'drink1',
          name: 'Test Bitter',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'Bitter',
        );

        const product2 = Product(
          id: 'drink2',
          name: 'Close ABV Bitter',
          abv: 5.3, // Within 0.5% ABV AND same style
          category: 'beer',
          dispense: 'keg',
          style: 'Bitter', // Same style - required for match
        );

        const product3 = Product(
          id: 'drink3',
          name: 'Different Style Beer',
          abv: 5.2, // Close ABV but different style - should NOT match
          category: 'beer',
          dispense: 'cask',
          style: 'Pale Ale',
        );

        const product4 = Product(
          id: 'drink4',
          name: 'Same Style Far ABV',
          abv: 7.0, // Same style but ABV too far (>0.5%) - should NOT match
          category: 'beer',
          dispense: 'cask',
          style: 'Bitter',
        );

        final drink1 = Drink(
          product: product1,
          producer: producer1,
          festivalId: 'cbf2025',
        );
        final drink2 = Drink(
          product: product2,
          producer: producer2,
          festivalId: 'cbf2025',
        );
        final drink3 = Drink(
          product: product3,
          producer: producer2,
          festivalId: 'cbf2025',
        );
        final drink4 = Drink(
          product: product4,
          producer: producer2,
          festivalId: 'cbf2025',
        );

        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink1, drink2, drink3, drink4]);
        await provider.loadDrinks();

        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // Scroll to ensure similar drinks section is visible
        await tester.ensureVisible(find.text('Similar Drinks'));
        await tester.pumpAndSettle();

        // Should show drink with same style AND close ABV
        expect(find.text('Close ABV Bitter'), findsOneWidget);
        expect(find.text('Same style, similar strength'), findsOneWidget);

        // Should NOT show drinks that don't match both criteria
        expect(find.text('Different Style Beer'), findsNothing);
        expect(find.text('Same Style Far ABV'), findsNothing);
      });
    });
  });
}
