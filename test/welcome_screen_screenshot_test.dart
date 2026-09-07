import 'package:cambridge_beer_festival/app_theme.dart';
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

import 'provider_test.mocks.dart';

const _producer = Producer(
  id: 'brewery1',
  name: 'Test Brewery',
  location: 'Cambridge, UK',
  products: [],
);

Drink _drink(
  String id,
  String name,
  String category, {
  bool? isVegan,
  int? gluten,
  int? sulphites,
}) => Drink(
  product: Product(
    id: id,
    name: name,
    abv: 4.2,
    category: category,
    dispense: 'cask',
    isVegan: isVegan,
    allergens: {'gluten': ?gluten, 'sulphites': ?sulphites},
  ),
  producer: _producer,
  festivalId: 'cbf2025',
);

void main() {
  group('WelcomeScreen Screenshot Tests', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    const festival = Festival(
      id: 'cbf2025',
      name: 'Cambridge Beer Festival 2025',
      dataBaseUrl: 'https://example.com',
      availableBeverageTypes: ['beer', 'cider', 'perry', 'mead', 'wine'],
    );

    setUp(() async {
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
      ).thenAnswer((_) async => festival.id);
      // A populated catalogue is the realistic first-run case — the drinks
      // load before this screen renders (ProviderInitializer holds the
      // loading screen until they arrive), and the dietary section is driven
      // off what they declare. An empty catalogue would render the fallback
      // path and show none of it.
      when(mockDrinkRepository.getDrinks(any)).thenAnswer(
        (_) async => [
          _drink('d1', 'Alpha Ale', 'beer', isVegan: true, gluten: 1),
          _drink('d2', 'Beta Bitter', 'beer', isVegan: false, gluten: 1),
          _drink('d3', 'Crisp Cider', 'cider'),
          _drink('d4', 'Perfect Perry', 'perry'),
          _drink('d5', 'Mead Mead', 'mead', sulphites: 1),
          _drink('d6', 'White Wine', 'wine', sulphites: 1),
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

    tearDown(() {
      provider.dispose();
    });

    // No drinks are loaded, so the category chips come from the festival's
    // beverage types — the same path a genuine first launch takes before the
    // catalogue arrives.
    Widget buildApp(Brightness brightness) {
      final router = GoRouter(
        initialLocation: '/welcome',
        routes: [
          GoRoute(
            path: '/welcome',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(path: '/:festivalId', builder: (_, _) => const Scaffold()),
        ],
      );
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: MaterialApp.router(
          theme: buildAppTheme(brightness),
          routerConfig: router,
        ),
      );
    }

    testWidgets('WelcomeScreen - light theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildApp(Brightness.light));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(WelcomeScreen),
        matchesGoldenFile('goldens/welcome_screen_light.png'),
      );
    });

    testWidgets('WelcomeScreen - dark theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildApp(Brightness.dark));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(WelcomeScreen),
        matchesGoldenFile('goldens/welcome_screen_dark.png'),
      );
    });
  });
}
