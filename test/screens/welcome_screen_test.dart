import 'package:cambridge_beer_festival/domain/models/models.dart';
import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_test.mocks.dart';

void main() {
  group('WelcomeScreen', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    const festival = Festival(
      id: 'cbf2025',
      name: 'Cambridge Beer Festival 2025',
      dataBaseUrl: 'https://example.com',
      availableBeverageTypes: ['beer', 'cider', 'international-beer'],
    );

    const producer = Producer(
      id: 'brewery1',
      name: 'Test Brewery',
      location: 'Cambridge, UK',
      products: [],
    );

    Drink drink(String id, String name, String category) => Drink(
      product: Product(
        id: id,
        name: name,
        abv: 4.2,
        category: category,
        dispense: 'cask',
      ),
      producer: producer,
      festivalId: festival.id,
    );

    final catalogue = [
      drink('d1', 'Alpha Ale', 'beer'),
      drink('d2', 'Crisp Cider', 'cider'),
      drink('d3', 'Perfect Perry', 'perry'),
    ];

    Future<void> setUpProvider({
      Map<String, Object> prefs = const {},
      List<Drink>? drinks,
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
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
      ).thenAnswer((_) async => festival.id);
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => drinks ?? catalogue);

      provider = BeerProvider(
        drinkRepository: mockDrinkRepository,
        festivalRepository: mockFestivalRepository,
        analyticsService: mockAnalyticsService,
      );
      await provider.initialize();
      await provider.loadDrinks();
    }

    /// Pumps the screen at `/welcome` with a stub drinks route, so leaving the
    /// screen lands somewhere observable.
    Future<void> pumpScreen(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/welcome',
        routes: [
          GoRoute(
            path: '/welcome',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: '/:festivalId',
            builder: (context, state) =>
                const Scaffold(body: Text('Drinks list')),
          ),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<BeerProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    tearDown(() {
      provider.dispose();
    });

    testWidgets('offers a chip for each category in the loaded catalogue', (
      tester,
    ) async {
      await setUpProvider();
      await pumpScreen(tester);

      expect(find.text('Beer'), findsOneWidget);
      expect(find.text('Cider'), findsOneWidget);
      expect(find.text('Perry'), findsOneWidget);
    });

    testWidgets(
      'falls back to the festival beverage types when nothing is loaded, '
      'mapping feed slugs to the categories drinks actually carry',
      (tester) async {
        await setUpProvider(drinks: []);
        await pumpScreen(tester);

        expect(find.text('Beer'), findsOneWidget);
        expect(find.text('Cider'), findsOneWidget);
        // international-beer's products are labelled 'foreign beer' — the
        // same label the category filter sheet shows for them.
        expect(find.text('Foreign beer'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('welcome-category-foreign beer')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Start browsing applies the picked category and leaves', (
      tester,
    ) async {
      await setUpProvider();
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('welcome-category-cider')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('welcome-continue')));
      await tester.pumpAndSettle();

      expect(provider.selectedCategories, {'cider'});
      expect(provider.hasCompletedOnboarding, isTrue);
      // The user ends up on the drinks list, filtered.
      expect(find.text('Drinks list'), findsOneWidget);
      expect(provider.drinks.map((d) => d.name), ['Crisp Cider']);
    });

    testWidgets('a visibility switch is applied on continue', (tester) async {
      await setUpProvider();
      await pumpScreen(tester);

      await tester.tap(
        find.byKey(const ValueKey('welcome-filter-availableOnly')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('welcome-continue')));
      await tester.pumpAndSettle();

      expect(provider.visibilityFilters, {DrinkVisibilityFilter.availableOnly});
    });

    testWidgets('does not offer the tasting-log filter to a new user', (
      tester,
    ) async {
      await setUpProvider();
      await pumpScreen(tester);

      expect(
        find.byKey(const ValueKey('welcome-filter-notTasted')),
        findsNothing,
      );
    });

    testWidgets('Skip completes onboarding without setting a filter', (
      tester,
    ) async {
      await setUpProvider();
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('welcome-category-cider')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('welcome-skip')));
      await tester.pumpAndSettle();

      expect(provider.hasCompletedOnboarding, isTrue);
      expect(provider.selectedCategories, isEmpty);
      expect(provider.drinks, hasLength(3));
      expect(find.text('Drinks list'), findsOneWidget);
    });

    testWidgets('seeds its chips from the preferences already saved', (
      tester,
    ) async {
      await setUpProvider(
        prefs: const {
          'selectedCategories': <String>['cider'],
          'onboardingComplete': true,
        },
      );
      await pumpScreen(tester);

      final chip = tester.widget<FilterChip>(
        find.byKey(const ValueKey('welcome-category-cider')),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('reads as an edit screen, not a welcome, on a return visit', (
      tester,
    ) async {
      await setUpProvider(prefs: const {'onboardingComplete': true});
      await pumpScreen(tester);

      expect(find.text('Drink preferences'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.textContaining('Welcome to'), findsNothing);
    });

    testWidgets('Cancel on a return visit changes nothing', (tester) async {
      await setUpProvider(
        prefs: const {
          'selectedCategories': <String>['cider'],
          'onboardingComplete': true,
        },
      );
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('welcome-category-beer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('welcome-skip')));
      await tester.pumpAndSettle();

      expect(provider.selectedCategories, {'cider'});
    });

    group('semantics', () {
      testWidgets('category chips announce their selection state', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await setUpProvider();
        await pumpScreen(tester);

        final node = tester.getSemantics(
          find.byKey(const ValueKey('welcome-category-cider')),
        );
        expect(node.label, 'Cider');
        expect(node.value, 'Not selected');

        await tester.tap(find.byKey(const ValueKey('welcome-category-cider')));
        await tester.pumpAndSettle();

        expect(
          tester
              .getSemantics(
                find.byKey(const ValueKey('welcome-category-cider')),
              )
              .value,
          'Selected',
        );
        handle.dispose();
      });

      testWidgets('visibility switches announce label, state and effect', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await setUpProvider();
        await pumpScreen(tester);

        final node = tester.getSemantics(
          find.byKey(const ValueKey('welcome-filter-availableOnly')),
        );
        expect(node.label, 'Only what is on now');
        expect(node.value, 'Off');
        expect(
          node.hint,
          'Hides drinks that are sold out or not yet on the bar',
        );
        handle.dispose();
      });

      testWidgets('both actions are labelled buttons', (tester) async {
        final handle = tester.ensureSemantics();
        await setUpProvider();
        await pumpScreen(tester);

        expect(
          tester
              .getSemantics(find.byKey(const ValueKey('welcome-continue')))
              .label,
          'Save preferences and start browsing',
        );
        expect(
          tester.getSemantics(find.byKey(const ValueKey('welcome-skip'))).label,
          'Skip',
        );
        handle.dispose();
      });
    });
  });
}
