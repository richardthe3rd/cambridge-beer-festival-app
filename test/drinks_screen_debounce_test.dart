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
  group('DrinksScreen search debounce', () {
    late MockDrinkRepository mockDrinkRepository;
    late MockFestivalRepository mockFestivalRepository;
    late MockAnalyticsService mockAnalyticsService;
    late BeerProvider provider;

    final testDrinks = [
      Drink(
        product: const Product(
          id: 'drink1',
          name: 'Alpha IPA',
          abv: 5.5,
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
      ),
      Drink(
        product: const Product(
          id: 'drink2',
          name: 'Beta Bitter',
          abv: 4.2,
          category: 'beer',
          dispense: 'cask',
          style: 'Bitter',
        ),
        producer: const Producer(
          id: 'brewery1',
          name: 'Test Brewery',
          location: 'Cambridge',
          products: [],
        ),
        festivalId: 'cbf2025',
      ),
      Drink(
        product: const Product(
          id: 'drink3',
          name: 'Gamma Stout',
          abv: 6.0,
          category: 'beer',
          dispense: 'keg',
          style: 'Stout',
        ),
        producer: const Producer(
          id: 'brewery2',
          name: 'Another Brewery',
          location: 'London',
          products: [],
        ),
        festivalId: 'cbf2025',
      ),
    ];

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
      when(mockFestivalRepository.getFestivals())
          .thenAnswer((_) async => festivalsResponse);
      when(mockFestivalRepository.getSelectedFestivalId())
          .thenAnswer((_) async => null);
      when(mockDrinkRepository.getDrinks(any))
          .thenAnswer((_) async => testDrinks);

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
        child: const MaterialApp(
          home: DrinksScreen(festivalId: 'cbf2025'),
        ),
      );
    }

    Future<void> openSearchBar(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Search drinks'));
      await tester.pumpAndSettle();
    }

    testWidgets('does not log analytics before debounce window elapses',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSearchBar(tester);

      await tester.enterText(find.byType(TextField).first, 'IPA');
      // 100ms is well within the 300ms debounce window
      await tester.pump(const Duration(milliseconds: 100));

      verifyNever(mockAnalyticsService.logSearch(any));
    });

    testWidgets('logs analytics once after debounce window elapses',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSearchBar(tester);

      await tester.enterText(find.byType(TextField).first, 'IPA');
      // 400ms is well past the 300ms debounce window
      await tester.pump(const Duration(milliseconds: 400));

      verify(mockAnalyticsService.logSearch('IPA')).called(1);
    });

    testWidgets('each keystroke resets the debounce window',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSearchBar(tester);

      final field = find.byType(TextField).first;

      // Type 'I', wait 250ms (within window), then type 'IP' to reset the timer
      await tester.enterText(field, 'I');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.enterText(field, 'IP');
      await tester.pump(const Duration(milliseconds: 250));

      // 500ms since 'I' was typed, but the timer was reset by 'IP' at 250ms.
      // The debounce window for 'IP' hasn't elapsed yet.
      verifyNever(mockAnalyticsService.logSearch(any));

      // Now let the debounce fire
      await tester.pump(const Duration(milliseconds: 300));
      verify(mockAnalyticsService.logSearch('IP')).called(1);
    });
  });
}
