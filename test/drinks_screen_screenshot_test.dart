// Golden baseline for issue #533's DrinksScreen extraction. Committed from
// the pre-refactor code (the CustomScrollView/Column tree built inline via
// the _buildX methods) so the extraction to private StatelessWidgets can be
// proven pixel-identical rather than merely "looks right." See
// ui-and-accessibility skill: goldens are updated deliberately, never
// blind-regenerated — this file's baseline must not be touched by the #533
// commit that follows it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cambridge_beer_festival/app_theme.dart';
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
  group('DrinksScreen Screenshot Tests', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    // Two breweries, two categories (beer + cider) and two styles so the
    // bottom controls' category/style FilterButtons are exercised and their
    // "Style" filter is actually shown (hasStyleFilter requires at least one
    // drink with a style).
    const producer1 = Producer(
      id: 'brewery1',
      name: 'Cambridge Brewing Company',
      location: 'Cambridge, UK',
      yearFounded: 1990,
      products: [],
    );

    const producer2 = Producer(
      id: 'brewery2',
      name: 'London Craft Ales',
      location: 'London, UK',
      yearFounded: 2000,
      products: [],
    );

    const productIpa = Product(
      id: 'drink1',
      name: 'Hoppy Heaven IPA',
      abv: 6.2,
      category: 'beer',
      style: 'IPA',
      dispense: 'cask',
    );

    const productStout = Product(
      id: 'drink2',
      name: 'Midnight Stout',
      abv: 4.8,
      category: 'beer',
      style: 'Stout',
      dispense: 'cask',
    );

    const productCider = Product(
      id: 'drink3',
      name: 'Orchard Gold',
      abv: 5.5,
      category: 'cider',
      dispense: 'keg',
    );

    final drink1 = Drink(
      product: productIpa,
      producer: producer1,
      festivalId: 'cbf2025',
    );
    final drink2 = Drink(
      product: productStout,
      producer: producer1,
      festivalId: 'cbf2025',
    );
    final drink3 = Drink(
      product: productCider,
      producer: producer2,
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
    });

    tearDown(() {
      provider.dispose();
    });

    // DrinksScreen reaches context.push/context.go for the overflow menu,
    // the festival banner (info screen) and drink-card taps, so — per
    // validation-and-qa — it must be pumped inside a real GoRouter with a
    // stub `/` route rather than a bare MaterialApp(home: ...).
    Widget createTestWidget(Brightness brightness) {
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
          // Stub for any internal context.go('/') / context.push target.
          GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        ],
      );
      return MaterialApp.router(
        // Use the real app theme so this golden covers appBarTheme,
        // navigationBarTheme and the text theme, not just the colour scheme
        // (#520).
        theme: buildAppTheme(brightness),
        routerConfig: router,
      );
    }

    testWidgets('DrinksScreen populated list - light theme', (tester) async {
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => [drink1, drink2, drink3]);
      await provider.loadDrinks();

      // Tall enough that both the drink list and the bottom filter controls
      // — the subtree the #533 extraction touches — are visible in one
      // frame.
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(createTestWidget(Brightness.light));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DrinksScreen),
        matchesGoldenFile('goldens/drinks_screen_light.png'),
      );
    });

    testWidgets('DrinksScreen populated list - dark theme', (tester) async {
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => [drink1, drink2, drink3]);
      await provider.loadDrinks();

      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(createTestWidget(Brightness.dark));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DrinksScreen),
        matchesGoldenFile('goldens/drinks_screen_dark.png'),
      );
    });
  });
}
