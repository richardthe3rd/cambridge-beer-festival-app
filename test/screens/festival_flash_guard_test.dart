import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/beer_provider.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_test.mocks.dart';

/// Every festival-scoped screen must refuse to render content belonging to a
/// festival other than the one in its route.
///
/// The router schedules `setFestival` in a post-frame callback
/// (`router.dart`'s `_festivalScopeRedirect`), so on a URL-driven festival
/// change — a cross-festival deep link on a warm app, browser back/forward, or
/// the post-init redirect in `main.dart` — the screen builds once *before* the
/// provider has switched. Without a guard that frame shows the previous
/// festival's data under the new festival's URL (issue #397).
///
/// Kept as one file rather than five, so adding a festival-scoped screen has an
/// obvious place to be added to the list.
void main() {
  late MockDrinkRepository mockDrinkRepository;
  late MockFestivalRepository mockFestivalRepository;
  late MockAnalyticsService mockAnalyticsService;
  late BeerProvider provider;

  const loadedFestivalId = 'cbf2025';
  const otherFestivalId = 'cbf2024';

  final drink = Drink(
    product: const Product(
      id: 'drink1',
      name: 'Stale Ale',
      abv: 4.5,
      category: 'beer',
      style: 'Bitter',
      dispense: 'cask',
    ),
    producer: const Producer(
      id: 'brewery1',
      name: 'Stale Brewery',
      location: 'Cambridge',
      products: [],
    ),
    festivalId: loadedFestivalId,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockDrinkRepository = MockDrinkRepository();
    mockFestivalRepository = MockFestivalRepository();
    mockAnalyticsService = MockAnalyticsService();

    when(mockFestivalRepository.getFestivals()).thenAnswer(
      (_) async => FestivalsResponse(
        festivals: [
          const Festival(
            id: loadedFestivalId,
            name: 'Cambridge Beer Festival 2025',
            dataBaseUrl: 'https://example.com',
          ),
        ],
        defaultFestivalId: loadedFestivalId,
        version: '1.0',
        baseUrl: 'https://example.com',
      ),
    );
    when(
      mockFestivalRepository.getSelectedFestivalId(),
    ).thenAnswer((_) async => null);
    when(mockDrinkRepository.getDrinks(any)).thenAnswer((_) async => [drink]);

    provider = BeerProvider(
      drinkRepository: mockDrinkRepository,
      festivalRepository: mockFestivalRepository,
      analyticsService: mockAnalyticsService,
    );
    await provider.initialize();
    await provider.loadDrinks();
  });

  tearDown(() => provider.dispose());

  Future<void> pump(WidgetTester tester, Widget screen) => tester.pumpWidget(
    ChangeNotifierProvider<BeerProvider>.value(
      value: provider,
      child: MaterialApp(home: screen),
    ),
  );

  // Each entry renders a screen for a festival the provider is NOT on.
  final mismatchedScreens = <String, Widget>{
    'DrinksScreen': const DrinksScreen(festivalId: otherFestivalId),
    'MyFestivalScreen': const MyFestivalScreen(festivalId: otherFestivalId),
    'DrinkDetailScreen': const DrinkDetailScreen(
      festivalId: otherFestivalId,
      drinkId: 'drink1',
    ),
    'BreweryScreen': const BreweryScreen(
      festivalId: otherFestivalId,
      breweryId: 'brewery1',
    ),
    'StyleScreen': const StyleScreen(
      festivalId: otherFestivalId,
      style: 'Bitter',
    ),
  };

  for (final entry in mismatchedScreens.entries) {
    final name = entry.key;
    final screen = entry.value;
    testWidgets('$name shows loading, not the other festival\'s data', (
      tester,
    ) async {
      expect(provider.currentFestival.id, loadedFestivalId);

      await pump(tester, screen);

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: '$name must hold a loading state until the provider catches up',
      );
      expect(
        find.text('Stale Ale'),
        findsNothing,
        reason:
            '$name must not render $loadedFestivalId data under a '
            '$otherFestivalId route',
      );
      expect(
        find.text('Stale Brewery'),
        findsNothing,
        reason: '$name must not render the previous festival\'s brewery',
      );
    });
  }

  testWidgets('screens render normally once the festival matches', (
    tester,
  ) async {
    await pump(tester, const DrinksScreen(festivalId: loadedFestivalId));
    await tester.pumpAndSettle();

    expect(find.text('Stale Ale'), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'The guard must not fire when the route and provider agree',
    );
  });
}
