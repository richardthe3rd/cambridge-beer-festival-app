import 'package:cambridge_beer_festival/models/models.dart';
import 'package:cambridge_beer_festival/providers/providers.dart';
import 'package:cambridge_beer_festival/screens/screens.dart';
import 'package:cambridge_beer_festival/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_test.mocks.dart';

void main() {
  group('DrinksScreen scroll position', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    // Enough drinks that the list scrolls well past a single screen height.
    final testDrinks = List.generate(40, (i) {
      return Drink(
        product: Product(
          id: 'drink$i',
          name: 'Drink $i',
          abv: 5.0,
          category: 'beer',
          dispense: 'cask',
          style: 'IPA',
        ),
        producer: const Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'cbf2025',
      );
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockDrinkRepository = MockDrinkRepository();
      mockFestivalRepository = MockFestivalRepository();
      mockAnalyticsService = MockAnalyticsService();

      const testFestival = Festival(
        id: 'cbf2025',
        name: 'Cambridge Beer Festival 2025',
        dataBaseUrl: 'https://test.example.com/cbf2025',
      );
      final festivalsResponse = FestivalsResponse(
        festivals: [testFestival],
        defaultFestivalId: 'cbf2025',
        baseUrl: 'https://example.com',
        version: '1.0.0',
      );
      when(
        mockFestivalRepository.getFestivals(),
      ).thenAnswer((_) async => festivalsResponse);
      when(
        mockFestivalRepository.getSelectedFestivalId(),
      ).thenAnswer((_) async => null);
      when(
        mockDrinkRepository.getDrinks(any),
      ).thenAnswer((_) async => testDrinks);

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

    Widget createTestWidget() {
      return ChangeNotifierProvider<BeerProvider>.value(
        value: provider,
        child: const MaterialApp(home: DrinksScreen(festivalId: 'cbf2025')),
      );
    }

    ScrollPosition listPosition(WidgetTester tester) {
      return tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
    }

    testWidgets('scrolling the list saves the offset on the provider', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(provider.drinksScrollOffset, 0.0);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      // The provider now holds the current scroll offset, not zero.
      expect(provider.drinksScrollOffset, greaterThan(0));
      expect(provider.drinksScrollOffset, listPosition(tester).pixels);
    });

    testWidgets('rebuilding the screen restores the saved scroll offset', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      final savedOffset = provider.drinksScrollOffset;
      expect(savedOffset, greaterThan(0));

      // Simulate the web navigate-away-and-back cycle: context.go() disposes
      // DrinksScreen, then a fresh instance is built when returning. Pumping
      // an unrelated tree forces dispose + re-create rather than an in-place
      // widget update (which would preserve the old State and its offset).
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(listPosition(tester).pixels, savedOffset);
    });

    testWidgets('a fresh screen with no saved offset starts at the top', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(listPosition(tester).pixels, 0.0);
    });
  });

  group('BeerProvider.saveDrinksScrollOffset', () {
    test('defaults to zero and round-trips without notifying listeners', () {
      SharedPreferences.setMockInitialValues({});
      final provider = BeerProvider(
        drinkRepository: MockDrinkRepository(),
        festivalRepository: MockFestivalRepository(),
        analyticsService: MockAnalyticsService(),
      );
      addTearDown(provider.dispose);

      expect(provider.drinksScrollOffset, 0.0);

      var notified = false;
      provider.addListener(() => notified = true);

      provider.saveDrinksScrollOffset(275.5);

      expect(provider.drinksScrollOffset, 275.5);
      // Scroll position is transient UI state — writing it must not trigger
      // a rebuild of everything listening to the provider.
      expect(notified, isFalse);
    });
  });
}
