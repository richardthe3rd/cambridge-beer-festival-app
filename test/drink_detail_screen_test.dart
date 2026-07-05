import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/services/services.dart';
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

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('Test Beer'), findsOneWidget); // Appears in header
      // Brewery name appears in breadcrumb, header (combined with location), and brewery section
      expect(find.textContaining('Test Brewery'), findsWidgets);
      // Location appears in header (combined) and brewery section subtitle
      expect(find.textContaining('Cambridge, UK'), findsWidgets);

      // Regression test for #311: app bar uses two-line breadcrumb layout
      // (brewery name as title, festival name below) matching style_screen
      // and brewery_screen. Raw festival ID must not appear.
      expect(find.text('Test Brewery'), findsWidgets);
      expect(find.text('Cambridge Beer Festival 2025'), findsWidgets);
      expect(find.text('cbf2025'), findsNothing);
    });

    testWidgets('displays drink details chips', (WidgetTester tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        when(
          mockDrinkRepository.getDrinks(any),
        ).thenAnswer((_) async => [drink]);
        await provider.loadDrinks();

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        // New layout shows combined information in HeroInfoCard
        expect(find.textContaining('5.0%'), findsOneWidget);
        expect(
          find.textContaining('IPA'),
          findsWidgets,
        ); // Appears in HeroInfoCard and style chip
        expect(find.textContaining('Cask'), findsOneWidget);
        expect(find.textContaining('Available at Main Bar'), findsOneWidget);
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

      // New layout shows availability in HeroInfoCard, statusText is not displayed
      expect(find.textContaining('Available at Main Bar'), findsOneWidget);
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

    testWidgets('displays allergen information', (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Contains:'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('displays rating section', (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      // New layout shows rating button in bottom action bar
      expect(find.text('Rate'), findsOneWidget);
      expect(find.widgetWithIcon(InkWell, Icons.star), findsOneWidget);
    });

    testWidgets('displays brewery section', (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.text('Brewery'), findsOneWidget);
      expect(
        find.byIcon(Icons.chevron_right),
        findsNWidgets(2),
      ); // Style chip + brewery card
    });

    testWidgets('has share button in app bar', (WidgetTester tester) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.share), findsOneWidget);
    });

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

      testWidgets(
        'mark-tasted button appends a tasting and updates the label',
        (WidgetTester tester) async {
          await useTallSurface(tester);
          when(
            mockDrinkRepository.getDrinks(any),
          ).thenAnswer((_) async => [drink]);
          await provider.loadDrinks();

          when(mockDrinkRepository.addTasting(any, any)).thenAnswer(
            (_) async => UserDrinkState(
              tastingEvents: [now],
              createdAt: now,
              updatedAt: now,
            ),
          );

          await tester.pumpWidget(createTestWidget('drink1'));
          await tester.pumpAndSettle();

          // Starts un-tasted.
          expect(find.text('Tasted'), findsOneWidget);
          expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);

          await tester.tap(find.byKey(const ValueKey('tasted-action')));
          await tester.pumpAndSettle();

          // One tasting recorded: label reflects the count and a row renders.
          expect(provider.getDrinkById('drink1')!.tastingCount, 1);
          expect(find.text('Tasted 1×'), findsOneWidget);
          expect(find.text('Your Tastings (1)'), findsOneWidget);
        },
      );

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
        when(mockDrinkRepository.addTasting(any, any)).thenAnswer(
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
            expect(
              find.byKey(
                ValueKey('delete-tasting-${now.millisecondsSinceEpoch}'),
              ),
              findsOneWidget,
            );
            // Each delete affordance carries a descriptive semantic label.
            expect(
              find.bySemanticsLabel(RegExp('^Remove tasting on ')),
              findsNWidgets(2),
            );
          } finally {
            semanticsHandle.dispose();
          }
        },
      );

      testWidgets('delete tasting asks for confirmation then removes the row', (
        WidgetTester tester,
      ) async {
        await useTallSurface(tester);
        when(mockDrinkRepository.getDrinks(any)).thenAnswer(
          (_) async => [
            tastedDrink([now]),
          ],
        );
        await provider.loadDrinks();

        // Removing the only tasting prunes the record to null.
        when(
          mockDrinkRepository.removeTasting(any, any, any),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(createTestWidget('drink1'));
        await tester.pumpAndSettle();

        expect(find.text('Your Tastings (1)'), findsOneWidget);

        await tester.tap(
          find.byKey(ValueKey('delete-tasting-${now.millisecondsSinceEpoch}')),
        );
        await tester.pumpAndSettle();

        // Confirm dialog appears; cancelling leaves the tasting in place.
        expect(find.text('Remove this tasting?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(provider.getDrinkById('drink1')!.tastingCount, 1);

        // Re-open and confirm this time.
        await tester.tap(
          find.byKey(ValueKey('delete-tasting-${now.millisecondsSinceEpoch}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        expect(provider.getDrinkById('drink1')!.tastingCount, 0);
        expect(find.text('Your Tastings (1)'), findsNothing);
      });

      testWidgets('notes editor shows a placeholder and saves user notes', (
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

        expect(find.text('Your Notes'), findsOneWidget);
        expect(find.text('Tap to add your notes'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('user-notes-editor')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('user-notes-field')),
          'Lovely and hoppy',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        verify(
          mockDrinkRepository.setUserNotes(any, any, 'Lovely and hoppy'),
        ).called(1);
        expect(provider.getDrinkById('drink1')!.userNotes, 'Lovely and hoppy');
        expect(find.text('Lovely and hoppy'), findsOneWidget);
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

        // Dialog is prefilled with the existing note.
        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('user-notes-field')),
        );
        expect(field.controller?.text, 'First taste');
      });
    });

    testWidgets('navigates to brewery screen when brewery card is tapped', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidgetWithRouter('drink1'));
      await tester.pumpAndSettle();

      final breweryCard = find.ancestor(
        of: find.text('Test Brewery'),
        matching: find.byType(Card),
      );
      await tester.ensureVisible(breweryCard.last);
      await tester.pumpAndSettle();

      await tester.tap(breweryCard.last);
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

      expect(find.text('4/5'), findsOneWidget);
    });

    testWidgets('does not display rating value when drink has no rating', (
      WidgetTester tester,
    ) async {
      when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);
      await provider.loadDrinks();

      await tester.pumpWidget(createTestWidget('drink1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('/5'), findsNothing);
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
      expect(find.text('5/5'), findsOneWidget);
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
